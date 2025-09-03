Shader "Custom/HatchingSP"
{
    Properties
    {
        _Tint ("Tint", Color) = (1, 1, 1, 1)
        _Scale("Line Scale", Float) = 0.2
        _BandThickness("Band Thickness", Float) = 0.5
        _OffsetAngle("Offset Angle", Float) = 0.0
        _BrtThres1("Brightness Threshold 1", Range(0.0, 1.0)) = 0.55
        _BrtThres2("Brightness Threshold 2", Range(2.0, 10.0)) = 2.0
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
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Shader Params
            float4 _Tint;
            float _Scale;
            float _BandThickness;
            float _OffsetAngle;
            float _BrtThres1;
            float _BrtThres2;

            struct VertexData
            {
                float4 position : POSITION;
                float3 normal : NORMAL;
            };
            
            struct FragInputData
            {
                float4 position : SV_POSITION;
                float3 normal : TEXCOORD1;
                float2 screenUV : TEXCOORD3;
            };

            // -------------------------------------------------------------------------------------------------------------------------------------------
            // Hatching

            float2 Rotate2D(float2 v, float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                return float2(c * v.x - s * v.y, s * v.x + c * v.y);
            }
            
            float BandPattern(float2 uv)
            {
                // direction
                Light light = GetMainLight();
                float2 lightDirProjected = TransformWorldToViewDir(light.direction).xy;
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
                return step(_BandThickness, bands.x);
            }

            // -------------------------------------------------------------------------------------------------------------------------------------------
            // Shaders
            
            FragInputData MyVertexProgram(VertexData v)
            {
                FragInputData outputData;
                outputData.position = TransformObjectToHClip(v.position.xyz);
                outputData.normal = TransformObjectToWorldNormal(v.normal);
                outputData.screenUV = (outputData.position.xy / outputData.position.w) * 0.5 + 0.5;
                return outputData;
            }
            
            half4 MyFragmentProgram(FragInputData i) : SV_Target
            {
                i.normal = normalize(i.normal);
                Light light = GetMainLight();
                float brightness = saturate(dot(i.normal, light.direction));
                float3 diffuseColor = LightingLambert(light.color, light.direction, i.normal);

                float aspect = _ScreenParams.x / _ScreenParams.y;
                float2 uvCentered = (i.screenUV - 0.5) * float2(aspect, 1);
                uvCentered *= -1.0;
                
                float gradBand = BandPattern(uvCentered);

                float mix = lerp(1.0f, _BrtThres2, 1.0f - brightness);
                float3 result = brightness < _BrtThres1 ?
                                                (_Tint.rgb * diffuseColor + 0.005 - gradBand)
                                                :
                                                _Tint.rgb * diffuseColor - gradBand / mix;
                return float4(result, 1);
            }
            
            ENDHLSL
        }

    }
    
}
