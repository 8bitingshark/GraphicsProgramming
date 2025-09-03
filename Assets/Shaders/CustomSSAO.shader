
Shader "Custom/CustomSSAO"
{
    Properties
    {
        _RotTex ("Rot Tex", 2D) = "white" {}
    }
    
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }
        
        Pass
        {
            Name "SSAO Pass"
            
            ZClip True
            ZTest Always
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            // SSAO mode
            #pragma shader_feature _SPHERICAL_METHOD
            // Occlusion function choice only one active
            #pragma shader_feature _OCCLUSION_V1 _OCCLUSION_V2 _OCCLUSION_V3

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            
            
            // Shader Params
            float _Radius;
            int _SampleCount;
            float3 _SSAOKernel[128];

            // Method Choice
            bool _WantSphericalMethod;
            // OcclusionFunction Choice
            int _OcclusionChoice;
            
            // Heuristic/Occlusion 1
            float _OcclusionBiasV1;

            // Heuristic/Occlusion 2
            float _OcclusionScale;
            float _OcclusionBiasV2;
            float _OcclusionPowerV2;

            // Heuristic/Occlusion 3
            float _FullOcclusionThreshold;
            float _NoOcclusionThreshold;
            float _OcclusionPowerV3;

            // Rot textures
            TEXTURE2D(_RotTex);
            SAMPLER(sampler_RotTex);
            
            struct Varyings
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            // -------------------------------------------------------------------------------------------------------------------------------------------
            // View Position reconstruction and coordinate space changes

            // Straightforward approach: from screenUV return to ViewSpace
            float3 reconstructViewPos(float2 screenUV)
            {
                float2 ndc = screenUV * 2 - 1;
                
                #if UNITY_REVERSED_Z
                    float rawDepth = SampleSceneDepth(screenUV);
                #else
                    // Adjust z to match NDC for OpenGL
                   float rawDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(screenUV));
                #endif
                
                // Using DirectX
                #if UNITY_UV_STARTS_AT_TOP
                    ndc.y *= -1.0;
                #endif
                
                float4 vProjectedPos = float4(ndc, rawDepth, 1);
                float4 vViewPosReconstructed = mul(UNITY_MATRIX_I_P, vProjectedPos);
                float3 vViewPos = vViewPosReconstructed.xyz / vViewPosReconstructed.w;  //this reconstructs the position with a -Z so with a RH system
                
                return vViewPos;
            }

            // Return to screenUV from ViewSpace coordinates
            float2 convertViewPosToScreenUV(float3 viewPos)
            {
                float4 clipPos = mul(UNITY_MATRIX_P, float4(viewPos, 1.0));
                clipPos /= clipPos.w;
                float2 ndc = clipPos.xy;
                
                #if UNITY_UV_STARTS_AT_TOP
                   ndc.y *= -1.0;
                #endif
                
                float2 reconstructedScreenUV = ndc * 0.5 + 0.5;
                
                return reconstructedScreenUV;
            }

            // -------------------------------------------------------------------------------------------------------------------------------------------
            // Occlusion Heuristics and Functions

            // from openGl tutorial
            float OcclusionFunction_v1(float fragEyeDepth, float reconstructedEyeDepth, float zSampleEyeDepth)
            {
                float rangeCheck = abs(fragEyeDepth - reconstructedEyeDepth) < _Radius ? 1.0 : 0.0; // check radius influence
                return (reconstructedEyeDepth <= zSampleEyeDepth - _OcclusionBiasV1 ? 1.0 : 0.0) * rangeCheck; // check occlusion with occlusionBias as epsilon 
            }

            // a slightly modification of the first one
            float OcclusionFunction_v2(float fragEyeDepth, float reconstructedEyeDepth, float zSampleEyeDepth)
            {
                float depthDelta = zSampleEyeDepth - reconstructedEyeDepth;
                float rangeCheck = abs(fragEyeDepth - reconstructedEyeDepth) < _Radius ? 1.0 : 0.0;

                float occlusion = saturate((depthDelta + _OcclusionBiasV2) / _Radius);
                occlusion = pow(occlusion, _OcclusionPowerV2);

                return occlusion * _OcclusionScale * rangeCheck;
            }

            // from the article "Principles and Practice of Screen Space Ambient Occlusion" of the book Game Programming Gems 8
            float OcclusionFunction_v3(float zSampleVS, float reconstructedEyeDepth)
            {
                float fDistance = zSampleVS - reconstructedEyeDepth;

                const float occlusionEpsilon = 0.001f; // avoid self-intersections
                
                if (fDistance > occlusionEpsilon)
                {
                    // Pass this distance there is no occlusion
                    float fNoOcclusionRange = _NoOcclusionThreshold - _FullOcclusionThreshold;

                    // Very close to the surface, 100% occluded
                    if (fDistance < _FullOcclusionThreshold)
                        return 1.0f;

                    // decay curve
                    return max(1.0 - pow(abs((fDistance - _FullOcclusionThreshold) / fNoOcclusionRange), _OcclusionPowerV3), 0.0f);
                }

                // distance < 0 : behind geometry, no contribution
                return 0.0f;
            }
            
            // Occlusion Test
            // check occlusion
            //return OcclusionFunction_v1(vViewPos.z, reconstructViewSpaceSurfacePoint.z, vSamplePoint.z);
            //return OcclusionFunction_v2(vViewPos.z, reconstructViewSpaceSurfacePoint.z, vSamplePoint.z);
            //return OcclusionFunction_v3(vSamplePoint.z, reconstructViewSpaceSurfacePoint.z);
            float TestOcclusion(float3 vViewPos, float3 vSamplePointDelta)
            {
                // find the 3D position of the sample point inside the hemisphere
                float3 vSamplePoint = vViewPos + _Radius * vSamplePointDelta;
                // find the screen uv
                float2 vSampleScreenUV = convertViewPosToScreenUV(vSamplePoint);
                // reconstruct the view space position of the sample
                float3 reconstructViewSpaceSurfacePoint = reconstructViewPos(vSampleScreenUV);

                /*
                if (vViewPos.z < 0)
                    vViewPos.z *= -1.0;

                if (reconstructViewSpaceSurfacePoint.z < 0)
                    reconstructViewSpaceSurfacePoint.z *= -1.0;

                if (vSamplePoint.z < 0)
                    vSamplePoint.z *= -1.0;
                */
                
                vViewPos.z = abs(vViewPos.z);
                reconstructViewSpaceSurfacePoint.z = abs(reconstructViewSpaceSurfacePoint.z);
                vSamplePoint.z = abs(vSamplePoint.z);

                float result = 0.0f;

                #if defined(_OCCLUSION_V1)
                    result = OcclusionFunction_v1(vViewPos.z, reconstructViewSpaceSurfacePoint.z, vSamplePoint.z);
                #elif defined(_OCCLUSION_V2)
                    result = OcclusionFunction_v2(vViewPos.z, reconstructViewSpaceSurfacePoint.z, vSamplePoint.z);
                #elif defined(_OCCLUSION_V3)
                    result = OcclusionFunction_v3(vSamplePoint.z, reconstructViewSpaceSurfacePoint.z);
                #endif

                return result;
            }
            
            // -------------------------------------------------------------------------------------------------------------------------------------------
            // Helper functions and tests:

            // with spherical sampling, if a sample is below the surface I can negate it so it lies above
            float3 negateSample(float3 vSample, float3 vNormal)
            {
                /*
                if (dot(vSample, vNormal) < 0)
                    return -vSample;
                return vSample;*/
                return vSample * sign(dot(vSample, vNormal));
            }

            // with spherical sampling you can reduce banding artifacts by reflecting the sample using the randomVector
            float3 reflectKernelSample( float3 vSample, float3 vRandomNormal) // with vRandomVector
            {
                return normalize(vSample - 2.0f * dot(vSample, vRandomNormal) * vRandomNormal);
            }

            bool IsNearTarget(float value, float target)
            {
                float epsilon = 0.001f;
                if (value > target - epsilon && value < target + epsilon)
                    return true;
                return false;
            }

            float angleBetweenRad(float3 v1, float3 v2)
            {
                float denom = sqrt(dot(v1,v1)) * sqrt(dot(v2,v2));
                float cosAlpha = dot(v1,v2) / denom;
                float3 crossP = cross(v1,v2);
                float crossNorm = sqrt(dot(crossP, crossP));
                float sinAlpha = crossNorm / denom;
                return atan2(sinAlpha, cosAlpha);
            }

            float angleBetweenDeg(float3 v1, float3 v2)
            {
                return RadToDeg(angleBetweenRad(v1,v2));
            }

            bool testOrthogonality(float3 tangent, float3 biTangent, float3 normal)
            {
                float a1 = angleBetweenDeg(tangent, biTangent);
                float a2 = angleBetweenDeg(tangent, normal);
                float a3 = angleBetweenDeg(biTangent, normal);

                return IsNearTarget(a1,a2) && IsNearTarget(a1, a3);
            }

            float4 testRotationOfKernelSamples(float3 i_vPos)
            {
                float2 vScreenUV = i_vPos.xy / _ScaledScreenParams.xy;
                
                #if UNITY_REVERSED_Z
                    float rawDepth = SampleSceneDepth(vScreenUV);
                #else
                   float rawDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(vScreenUV));
                #endif

                // early out
                #if UNITY_REVERSED_Z
                    if(rawDepth < 0.0001)
                        return half4(1,1,1,1);
                #else
                    if(rawDepth > 0.9999)
                        return half4(1,1,1,1);
                #endif
                
                const float rotTextureSize = 4.0;
                float2 textureScale = _ScaledScreenParams.xy / float2(rotTextureSize, rotTextureSize);
                float3 vRandomVector = normalize(SAMPLE_TEXTURE2D(_RotTex, sampler_RotTex, vScreenUV * textureScale).xyz * 2.0 - float3(1,1,1));
                vRandomVector.z = 0.0f;
                vRandomVector = normalize(vRandomVector);
                
                float3 vSampledNormalWS = SampleSceneNormals(vScreenUV);
                float3 vNormalVS = TransformWorldToViewNormal(normalize(vSampledNormalWS), true);
                
                float3 vTangent = normalize(vRandomVector - dot(vRandomVector, vNormalVS) * vNormalVS);
                float3 vBitangent = normalize(cross(vNormalVS, vTangent));
                
                bool dotAccum = true;

                UNITY_UNROLL
                for (int i = 0; i < _SampleCount; ++i)
                {
                    float3 sample = _SSAOKernel[i];
                    float3 vSamplePointDelta = sample.x * vTangent + sample.y * vBitangent + sample.z * vNormalVS;
                    
                    float dotResult = dot(vSamplePointDelta, vNormalVS);
                    dotAccum = dotAccum && (dotResult > 0.0f || IsNearTarget(dotResult, 0.0f));
                }

                float4 result = dotAccum ? float4(0,1,0,1) : float4(1,0,0,1);
                return result;
            }
            
            // -------------------------------------------------------------------------------------------------------------------------------------------
            // SSAO
            
            float4 CustomSSAO(float3 i_vPos)
            {
                float2 vScreenUV = i_vPos.xy / _ScaledScreenParams.xy;

                // Sample the depth from the Camera depth texture.
                #if UNITY_REVERSED_Z
                    float rawDepth = SampleSceneDepth(vScreenUV);
                #else
                    // Adjust z to match NDC for OpenGL
                   float rawDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(vScreenUV));
                #endif
                
                // Early out for the sky
                #if UNITY_REVERSED_Z
                    // Case for platforms with REVERSED_Z, such as D3D.
                    if(rawDepth < 0.0001)
                        return half4(1,1,1,1);
                #else
                    // Case for platforms without REVERSED_Z, such as OpenGL.
                    if(rawDepth > 0.9999)
                        return half4(1,1,1,1);
                #endif

                // reconstruct view space position
                float3 vFragmentViewPos = reconstructViewPos(vScreenUV);
                
                // sampling the random vector for rotation using a tiled texture
                const float rotTextureSize = 4.0;
                float2 textureScale = _ScaledScreenParams.xy / float2(rotTextureSize, rotTextureSize); // to tile the random texture across the RT
                // get the random vector in tangent space, sampling the tiled texture 
                float3 vRandomVector = normalize(SAMPLE_TEXTURE2D(_RotTex, sampler_RotTex, vScreenUV * textureScale).xyz * 2.0 - float3(1,1,1));
                // clean vector
                vRandomVector.z = 0.0f;
                vRandomVector = normalize(vRandomVector);
                
                // get the normal from the _CameraNormalTexture
                // Note: using default LitShader the "DepthNormals" pass store world space normals without remapping into [0,1]
                // So there is no need to return to [-1,1] after sampled
                // It could be easier to write a custom normal pass to store directly the view space normals
                // the below sampling uses the same normal pass of the LitShader
                float3 vSampledNormalWS = SampleSceneNormals(vScreenUV);
                float3 vNormalVS = TransformWorldToViewNormal(normalize(vSampledNormalWS), true);

                // Compute Tangent and bTangent to build a TBN to rotate the sample according to the normal
                float3 vTangent = normalize(vRandomVector - dot(vRandomVector, vNormalVS) * vNormalVS);
                float3 vBitangent = normalize(cross(vNormalVS, vTangent));
                
                half fAccumBlock = 0;

                // UNITY_UNROLL -> only if _SampleCount won't change
                for (int i = 0; i < _SampleCount; ++i)
                {
                    float3 sample = _SSAOKernel[i];
                    float3 vSamplePointDelta;
                    
                    // SPHERICAL METHOD
                    // - Check : https://mtnphil.wordpress.com/2013/06/26/know-your-ssao-artifacts/#:~:text=float3x3%20GetRotationMatrix,tangent%2C%20bitangent%2C%20surfaceNormal%29%3B
                    // - Without random perturbation of the samples you can end up having light regions near the corners
                    // - Possible improvement: reject samples that are too much parallel to the surface to avoid
                    //   some artifacts such as banding or wrong occlusion.
                    // - In the article the author uses 0.15 for the threshold value.
                    //   This value may depends from the resolution of the depth buffer and how far the objects are from the camera,
                    //   so where the resolution of the depth buffer is decreased. In the spherical case it means to compute the AO with less samples
                    // - Without the rotation of the kernel the are many banding artifacts. Using spherical sample rays,
                    //   you can reflect them about the random normal vector to reduce bands.
                    // - The code below with a lot of samples introduce much more occlusion and it doesn't remove the light regions artifacts,
                    //   but removes banding.
                    //   With few sample increase some "god" aura around some surfaces and there are more bandings.
                    #if defined(_SPHERICAL_METHOD)
                        vSamplePointDelta = reflectKernelSample(sample, vRandomVector);
                        vSamplePointDelta = negateSample(vSamplePointDelta, vNormalVS);
                    
                    // HEMISPHERICAL METHOD
                    // - With this method you can't simply reflect the rays using the random vector because it is likely that
                    //   your points will no longer be in a single hemisphere.
                    //   You must orient your hemisphere along your surface, and then use the random normal to rotate it to an arbitrary position.
                    // - Generally is used Gram-Schmidt process to construct an orthogonal basis,
                    //   from which we generate a rotation matrix used to rotate the rays in the sample kernel.
                    //   This works well when the surface faces towards the viewer.
                    //   It can generate artifacts when the surface is more perpendicular to the screen however.
                    #else
                        vSamplePointDelta = sample.x * vTangent + sample.y * vBitangent + sample.z * vNormalVS; // applying the rotation
                    #endif
                    
                    float fBlock = TestOcclusion(vFragmentViewPos, vSamplePointDelta);
                    fAccumBlock += fBlock;
                }

                fAccumBlock /= _SampleCount;
                float4 result = float4(1 - fAccumBlock.xxx, 1);
                
                return result;
            }
            
            // -------------------------------------------------------------------------------------------------------------------------------------------
            
            // Vertex Shader
            Varyings MyVertexProgram(uint vertexID : SV_VertexID)
            {
                Varyings outputData;
                outputData.position = GetFullScreenTriangleVertexPosition(vertexID);
                outputData.uv = GetFullScreenTriangleTexCoord(vertexID);
                return outputData;
            }

            // Fragment Shader
            half4 MyFragmentProgram(Varyings i) : SV_Target
            {
                return CustomSSAO(i.position.xyz);
            }
            
            ENDHLSL
        }

    }
    
}