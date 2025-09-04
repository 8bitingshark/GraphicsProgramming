Shader "Custom/GustaveDoreHatching"
{
    Properties
    {
        _GradientColor1 ("GradientColor1", Color) = (1, 1, 1, 1)
        _GradientColor2 ("GradientColor2", Color) = (0, 0, 0, 1)
        _Tiling("Tiling (bands per screen height)", Float) = 20.0
        _Offset("Offset", Float) = 0.0
        _Invert("Invert (0 or 1)", Float) = 0.0
        _Bands("Band Hardness 0=grad 1=stripes", Range(0,1)) = 1.0
        _Smooth("Edge Smooth", Range(0,1)) = 0.0
        _Triangle("Use Triangle Ramp", Float) = 1.0
        _LightMultiplier("Light Multiplier", Float) = 2.0
        _BandsMultiplier("Bands Multiplier", Float) = 2.0
        _GammaValue("Gamma Value", Float) = 0.2
        _MaterialTex ("Material Tex", 2D) = "white" {}
        _TextureMultiplier ("Texture Multiplier", Range (0, 1)) = 0
        _VoronoiTex ("Voronoi Tex", 2D) = "white" {}
        _NoiseFrequency ("Noise Frequency", Float) = 0.1
        _NoiseAmp ("Noise Amplitude", Float) = 0.01
        _NoiseAmount("Noise Amount", Range(0, 1)) = 0
        _PaperTex ("Paper Tex", 2D) = "white" {}
    }
    
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }
        
        Pass
        {
            Name "Forward"
		    Tags { "LightMode"="UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS
            //#pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Shader Params
            float4 _GradientColor1;
            float4 _GradientColor2;
            float _Tiling;    // bands per screen height
            float _Offset;    // scroll amount (in bands units)
            float _Invert;    // 0 or 1
            float _Bands;     // mix grad->bands
            float _Smooth;    // band edge smoothing 0-1
            float _Triangle;  // 0 saw, 1 triangle
            float _LightMultiplier;
            float _BandsMultiplier;
            float _GammaValue;
            TEXTURE2D(_MaterialTex);
            SAMPLER(sampler_MaterialTex);
            float _TextureMultiplier;
            float _NoiseFrequency;
            float _NoiseAmp;
            float _NoiseAmount;
            TEXTURE2D(_VoronoiTex);
            SAMPLER(sampler_VoronoiTex);
            float4 _VoronoiTex_ST;
            TEXTURE2D(_PaperTex);
            SAMPLER(sampler_PaperTex);
            float4 _PaperTex_ST;
            
            struct VertexData
            {
            float4 position : POSITION;
            float3 normal : NORMAL;
            float2 uv : TEXCOORD0;
            };
            
            struct FragInputData
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float2 camUV : TEXCOORD3;
            };

            // -------------------------------------------------------------------------------------------------------------------------------------------
            // Rot Utils
            
            float2 Rotate2D(float2 v, float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                return float2(c * v.x - s * v.y, s * v.x + c * v.y);
            }

            // -------------------------------------------------------------------------------------------------------------------------------------------
            // Bands Pattern
            
            // For procedural bands
            float TriangleWave(float x)
            {
                // periodic [0,1] triangle from repeating x
                // frac returns [0,1); map to [-1,1], abs, invert
                float f = frac(x);            // 0..1
                f = abs(f * 2.0 - 1.0);       // 1 -> 0 -> 1 triangle
                return f;                     // 0..1 (peak at 0 & 1, valley at 0.5)
            }

            float SawWave(float x)
            {
                return frac(x); // 0..1 ramp
            }

            float BandsFromWave(float w, float hardness, float smooth)
            {
                // hardness=0 -> return w (gradient)
                // hardness=1 -> hard 2-tone bands (0/1) with smoothing
                // We'll map w to binary stripes: step(0.5) type.
                float stripes = step(0.5, w); // 0..1 hard split in middle
                if (smooth > 0.0)
                {
                    float edge = smoothstep(0.5 - 0.5 * smooth, 0.5 + 0.5 * smooth, w);
                    stripes = edge;
                }
                return lerp(w, stripes, hardness);
            }

            // -------------------------------------------------------------------------------------------------------------------------------------------
            // Noise
            
            float hash(float2 p)
            {
                return frac(sin(dot(p, float2(12.9898,78.233))) * 43758.5453);
            }
            
            float2 StaticDistortionUV(float2 uv)
            {
                float2 noiseUV = float2(
                hash(uv * _NoiseFrequency),
                hash(uv * _NoiseFrequency + 100.0)
                 );

                // Riporta il noise in [-0.5, +0.5] e applica ampiezza
                return uv + _NoiseAmount * (noiseUV - 0.5) * _NoiseAmp;
            }

            // -------------------------------------------------------------------------------------------------------------------------------------------
            // Handles multiple lights
            // works with forward/forward+ of URP
            
            void ApplyLighting(float3 positionWS, float3 normalWS, inout float brightness, inout float3 diffuseColor)
            {
                // main light
                Light light = GetMainLight();
                brightness = saturate(dot(normalWS, light.direction));
                diffuseColor = LightingLambert(light.color, light.direction, normalWS);

                // additional lights
                #if defined(_ADDITIONAL_LIGHTS)
                    #if defined(_FORWARD_PLUS)
                        UNITY_LOOP
                        for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); ++lightIndex)
                        {
                            Light light = GetAdditionalLight(lightIndex, positionWS, half4(1,1,1,1));
                            float NdotL = saturate(dot(normalWS, light.direction));
                            brightness   += NdotL;
                            diffuseColor += LightingLambert(light.color, light.direction, normalWS);
                        }
                    #else
                        int additionalLightCount = GetAdditionalLightsCount();
                        for (int lightIndex = 0; lightIndex < additionalLightCount; ++lightIndex)
                        {
                            Light additionalLight = GetAdditionalLight(lightIndex, positionWS);
                            brightness += saturate(dot(normalWS, additionalLight.direction));
                            diffuseColor += LightingLambert(additionalLight.color, additionalLight.direction, normalWS);
                        }
                    #endif

                #endif
            }
            
            // -------------------------------------------------------------------------------------------------------------------------------------------
            // Shaders
            
            FragInputData MyVertexProgram(VertexData v)
            {
                VertexPositionInputs posInputs = GetVertexPositionInputs(v.position.xyz);
                
                FragInputData outputData;
                outputData.uv = v.uv;
                outputData.position = TransformObjectToHClip(v.position.xyz);
                outputData.normalWS = TransformObjectToWorldNormal(v.normal);
                outputData.positionWS = TransformObjectToWorld(v.position.xyz);
                
                float2 clipCoord = posInputs.positionCS.xy; // before perspective division
                outputData.camUV = clipCoord * 0.5 + 0.5;

                return outputData;
            }
            
            half4 MyFragmentProgram(FragInputData i) : SV_Target
            {
                float brightness = 0.0f;
                float3 diffuseColor;
                i.normalWS = normalize(i.normalWS);
                ApplyLighting(i.positionWS, i.normalWS, brightness, diffuseColor);
                
                // Using normals in VS to have all the lines aligned with the camera
                float3 normalVS = TransformWorldToViewNormal(i.normalWS, true);

                // turn in an angle
                float angle = atan2(normalVS.y, normalVS.x);
                // remap into [-1,1]
                float remappedAngle = angle / PI;
                // now remap into [0,1]
                float angle01 = remappedAngle * 0.5 + 0.5;
                // we can use this value to bend the lines but not using a continuous value
                // but divide it into chunks
                angle01 *= 8;
                angle01 = floor(angle01);
                angle01 /= 8;
                angle01 *= -127.0;
                
                // Adding some noise
                float2 distortedCamUV = StaticDistortionUV(i.camUV);

                // sample voronoi texture
                float3 vorSample = SAMPLE_TEXTURE2D(_VoronoiTex, sampler_VoronoiTex, TRANSFORM_TEX(i.uv, _VoronoiTex)).rgb;
                // calculate patch angle
                float patchAngle = vorSample.b * 6.28318; // rotation per patch
                
                // Pattern along Y axis with camera UV
                float2 rotatedUV = Rotate2D(distortedCamUV, angle01 + patchAngle);
                float axis = rotatedUV.y * _Tiling + _Offset;
                
                // Base waveform
                float baseWave = (_Triangle > 0.5) ? TriangleWave(axis) : SawWave(axis);
                // Convert in hard bands
                float bandVal = BandsFromWave(baseWave, saturate(_Bands), saturate(_Smooth));
                // Invert if asked
                if (_Invert > 0.5) bandVal = 1.0 - bandVal;

                // Ink Color
                float3 inkColor = lerp(_GradientColor2.rgb, _GradientColor1.rgb, bandVal);

                // Adding gamma
                inkColor = pow(abs(inkColor), 1.0 / max(_GammaValue, 0.01));
                
                // Sampling eventual texture
                float4 textureColor = SAMPLE_TEXTURE2D(_MaterialTex, sampler_MaterialTex, i.uv);

                // Combining light, texture and bands
                float3 textureLighting = (textureColor.rgb + _TextureMultiplier) * diffuseColor.xyz; //* diffuseColor.xyz
                float3 lightColorMultiplied = textureLighting * _LightMultiplier;
                float3 inkColorMultiplied = inkColor * _BandsMultiplier;
                float3 result = lightColorMultiplied - inkColorMultiplied;
                result = saturate(result);

                // Adding a paper texture 
                float3 paperColor = SAMPLE_TEXTURE2D(_PaperTex, sampler_PaperTex, TRANSFORM_TEX(i.uv, _PaperTex)).rgb;
                result = saturate(result * paperColor);
                
                return float4(result, 1);
            }
            
            ENDHLSL
        }

        // DepthNormals
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }
            
            ZWrite On
            Cull Back
            
            HLSLPROGRAM
            #pragma vertex DN_Vert
            #pragma fragment DN_Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct A { float4 pos:POSITION; float3 normal:NORMAL; };
            struct V { float4 pos:SV_POSITION; float3 normalWS:TEXCOORD0; };
            V DN_Vert(A v){
                V o;
                VertexPositionInputs pos = GetVertexPositionInputs(v.pos.xyz);
                o.pos = pos.positionCS;
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }
            half4 DN_Frag(V i):SV_Target{
                float3 n = normalize(i.normalWS);
                return half4(n,1);
            }
            ENDHLSL
        }
    }
    
}
