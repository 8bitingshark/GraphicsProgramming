Shader "Custom/HatchingWS"
{
    Properties
    {
        _Scale("Line Scale", Float) = 0.2
        _BandThickness("Band Thickness", Float) = 0.5
        _ShadowThreshold("ShadowThreshold", Range(0, 1)) = 0.5
        _OffsetAngle("Offset Angle", Float) = 0.0
        
        _GradientColor1 ("GradientColor1", Color) = (1, 1, 1, 1)
        _GradientColor2 ("GradientColor2", Color) = (0, 0, 0, 1)
        _LightMultiplier("Light Multiplier", Float) = 2.0
        _BandsMultiplier("Bands Multiplier", Float) = 2.0
        _MaterialTex ("Material Tex", 2D) = "white" {}
        _TextureAddValue ("Texture Add Value", Range (0, 1)) = 0
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
            float _Scale;
            float _BandThickness;
            float _ShadowThreshold;
            float _OffsetAngle;

            float4 _GradientColor1;
            float4 _GradientColor2;
            float _LightMultiplier;
            float _BandsMultiplier;
            TEXTURE2D(_MaterialTex);
            SAMPLER(sampler_MaterialTex);
            float _TextureAddValue;
            TEXTURE2D(_VoronoiTex);
            SAMPLER(sampler_VoronoiTex);
            float _NoiseFrequency;
            float _NoiseAmp;
            float _NoiseAmount;
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
                float3 worldPos : TEXCOORD2;
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
            // Band Pattern

            float BandPattern(float2 uv)
            {
                // direction
                Light light = GetMainLight();
                float2 lightDirProjected = light.direction.xy;
                lightDirProjected = normalize(lightDirProjected);
                lightDirProjected = Rotate2D(lightDirProjected, _OffsetAngle);

                // project 
                float gradient = dot(uv, lightDirProjected);
                
                // scale frequency
                gradient *= _Scale;

                // generate bands
                float2 bands = frac(gradient);

                // [-1,1] -> [0,1]
                bands = bands * 0.5f + 0.5f;

                // control sharpness
                return step(_BandThickness, bands).x;
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
                FragInputData outputData;
                outputData.position = TransformObjectToHClip(v.position.xyz);
                outputData.uv = v.uv;
                outputData.normalWS = TransformObjectToWorldNormal(v.normal);
                outputData.worldPos = TransformObjectToWorld(v.position.xyz);

                return outputData;
            }
            
            half4 MyFragmentProgram(FragInputData i) : SV_Target
            {
                float brightness = 0.0f;
                float3 diffuseColor;
                i.normalWS = normalize(i.normalWS);
                ApplyLighting(i.worldPos, i.normalWS, brightness, diffuseColor);

                // Adding some noise
                float2 distortedUV = StaticDistortionUV(i.worldPos.xy);
                
                // turn this gradients into an angle
                float angle = atan2(i.normalWS.y, i.normalWS.x);
                // remap into [-1,1]
                float remappedAngle = angle / PI;
                // now remap into [0,1]
                float angle01 = Remap(-1, 1, 0, 1, remappedAngle);
                // we can use this value to bend the lines but not using a continuous value
                // but divide it into chunks
                angle01 *= 8;
                angle01 = floor(angle01);
                angle01 /= 8;
                angle01 *= -64.0; // magic number to create convergence between chunks ?? // -32
                
                float3 vorSample = SAMPLE_TEXTURE2D(_VoronoiTex, sampler_VoronoiTex, TRANSFORM_TEX(i.uv, _VoronoiTex)).rgb;
                float patchAngle = vorSample.b * 6.28318;

                // USING WORLD SPACE
                float2 rotatedUV = Rotate2D(distortedUV, angle01 + patchAngle);

                float grad2 = BandPattern(rotatedUV);

                // Ink Color
                float3 inkColor = lerp(_GradientColor2.rgb, _GradientColor1.rgb, grad2);

                // Sampling eventual texture
                float4 textureColor = SAMPLE_TEXTURE2D(_MaterialTex, sampler_MaterialTex, i.uv);

                // Combining light, texture and bands
                float3 textureLighting = textureColor.rgb + _TextureAddValue;
                float3 lightColorMultiplied = textureLighting * _LightMultiplier; // * diffuseColor.xyz
                float3 inkColorMultiplied = inkColor * _BandsMultiplier;
                float3 result = lightColorMultiplied - inkColorMultiplied;
                result = saturate(result);

                // adding a paper texture 
                float3 paperColor = SAMPLE_TEXTURE2D(_PaperTex, sampler_PaperTex, TRANSFORM_TEX(i.uv, _PaperTex)).rgb;
                result = saturate(result * paperColor);

                float3 colorFinal = brightness < _ShadowThreshold ? float3(0,0,0) : result;
                return float4(colorFinal, 1);
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
