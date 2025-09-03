Shader "Custom/GaussianBlur"
{
    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    // The Blit.hlsl file provides the vertex shader (Vert),
    // the input structure (Attributes), and the output structure (Varyings)
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    #define E 2.71828f

    // shader params
    float _Spread;
    uint  _GridSize;

    float gaussian(int x)
    {
	float sigma_squ = _Spread * _Spread;
	return (1 / sqrt(TWO_PI * sigma_squ)) * pow(E, -(x * x) / (2 * sigma_squ));
    }
    
    half4 frag_horizontal(Varyings IN) : SV_TARGET
    {
        float3 color = 0;
        float gridSum = 0;

        int upper = ((_GridSize - 1) / 2);
	    int lower = -upper;

        for (int x = lower; x < upper + 1; ++x)
        {
            float gaussValue = gaussian(x);
            gridSum += gaussValue;
            float2 uv = IN.texcoord + float2(_BlitTexture_TexelSize.x * x, 0.0f);
            color += gaussValue * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb;
        }

        color /= gridSum;
        return float4(color, 1);
    }

    half4 frag_vertical(Varyings IN) : SV_TARGET
    {
        float3 color = 0;
        float gridSum = 0;

        int upper = ((_GridSize - 1) / 2);
	    int lower = -upper;

        for (int y = lower; y < upper + 1; ++y)
        {
            float gaussValue = gaussian(y);
            gridSum += gaussValue;
            float2 uv = IN.texcoord + float2(0.0f, _BlitTexture_TexelSize.y * y);
            color += gaussValue * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb;
        }

        color /= gridSum;
        return float4(color, 1);
        
    }
    
    ENDHLSL
    
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        
        Pass
        {
            Name "HorizontalBlurRenderPass"

            ZClip True
            ZTest Always
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment frag_horizontal
            
            ENDHLSL
        }
        
        Pass
        {
            Name "VerticalBlurRenderPass"
            
            ZClip True
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment frag_vertical
            
            ENDHLSL
        }
    }
    
}

