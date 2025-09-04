Shader "Hidden/AOBlit"
{
     HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    half4 frag_blit(Varyings i) : SV_TARGET
    {
        // AO viene da una UNorm lineare (R8G8B8A8_UNorm)
        half ao = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord).r;

        // Opzionale: se il target è sRGB, l'hardware farà Linear->sRGB in uscita.
        // Per evitare l'effetto "schiarito" in preview, puoi compensare così:
        #if !defined(UNITY_COLORSPACE_GAMMA)
            // Compensa la sRGB write: encode^-1
            ao = SRGBToLinear(ao);
        #endif

        return half4(ao, ao, ao, 1.0h);
        
    }
    
    ENDHLSL
    
    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" }
        Pass
        {
            Name "AOBlitPass"
            
            ZTest Always Cull Off ZWrite Off
            Blend One Zero

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag_blit
            
            ENDHLSL
        }
    }
}