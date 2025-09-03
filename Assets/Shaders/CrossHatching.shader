Shader "Custom/CrossHatchingSP"
{
    Properties
    {
        _Tint ("Tint", Color) = (1, 1, 1, 1)
        _LineDensity("Line Density", Float) = 100
        _LineThickness("Line Thickness", Range(0.0, 1.0)) = 0.2
        _LineContrast("Line Contrast", Range(0.001, 1.0)) = 0.3
        _LineOpacity("Line Opacity", Range(0.0, 1.0)) = 0.8
        _BrtThres1("Brightness Threshold 1", Range(0.0, 1.0)) = 0.55
        _BrtThres2("Brightness Threshold 2", Range(0.0, 1.0)) = 0.2
        _BrtThres3("Brightness Threshold 3", Range(0.0, 1.0)) = 0.1
        
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
            #include "Assets/Shaders/RemapUtils.hlsl"

            // Shader Params
            float4 _Tint;
            float _LineDensity;
            float _LineThickness;
            float _LineContrast;
            float _LineOpacity;
            float _BrtThres1;
            float _BrtThres2;
            float _BrtThres3;

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
            
            inline float InvLerpClamped(float value, float a, float b)
            {
                return saturate( (value - a) / (b - a) );
            }

            float SingleHatching(float2 screenUV, float brightness, float2 dirProjected)
            {
                float grad = dot(screenUV, dirProjected); // centered UV

                // sawtooth
                float dot_scaled = frac(grad * _LineDensity);
                // remap from 0,1 to -1,1
                float gradient = RemapValue(dot_scaled, 0.0, 1.0, -1.0, 1.0, true);
                // triangular wave, line distance field
                gradient = abs(gradient);
                
                float t = (gradient - _LineThickness) / _LineContrast;
                gradient = smoothstep(0.0, 1.0, t);

                // ink amount mask
                float inkMask = InvLerpClamped(brightness, 0.4, 0.9);

                // multiply together the inverse of the two values
                float invGradient = 1.0 - gradient;
                float invInkMask = 1.0 - inkMask;

                float result = invGradient * invInkMask * _LineOpacity;
                float invResult = 1.0 - result;
                
                return invResult;
            }

            float2 Rotate2D(float2 v, float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                return float2(c * v.x - s * v.y, s * v.x + c * v.y);
            }
            
            float ProgressiveHatching(float2 screenUV, float brightness, float2 baseDir)
            {
                float2 dir1 = normalize(baseDir);
                float2 dir2 = normalize(Rotate2D(dir1, radians(45)));
                float2 dir3 = normalize(Rotate2D(dir1, radians(90)));
                float2 dir4 = normalize(Rotate2D(dir1, radians(120)));

                float4 hatchLayers;
                hatchLayers.x = SingleHatching(screenUV, brightness, dir1);
                hatchLayers.y = SingleHatching(screenUV, brightness, dir2);
                hatchLayers.z = SingleHatching(screenUV, brightness, dir3);
                hatchLayers.w = SingleHatching(screenUV, brightness, dir4);

                if (brightness > _BrtThres1)
                {
                    return hatchLayers.x;
                }
                if (brightness > _BrtThres2)
                {
                    return hatchLayers.x * hatchLayers.y;
                }
                if (brightness > _BrtThres3)
                {
                    return hatchLayers.x * hatchLayers.y * hatchLayers.z;
                }
     
                return hatchLayers.x * hatchLayers.y * hatchLayers.z * hatchLayers.w;
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

                float aspect = _ScreenParams.x / _ScreenParams.y;
                
                // i.screenUV - 0.5  move the uv origin to the center of the screen
                // flipping allow to avoid the line space to rotate in the opposite direction from the camera
                float2 uvCentered = (i.screenUV - 0.5) * float2(aspect, 1);
                uvCentered *= -1.0;
                
                float2 lightDirProjected = TransformWorldToViewDir(light.direction).xy;
                lightDirProjected = normalize(lightDirProjected);
                
                float hatch = ProgressiveHatching(uvCentered, brightness, lightDirProjected);
                return float4(_Tint.rgb * hatch, 1);
            }
            
            ENDHLSL
        }

    }
    
}
