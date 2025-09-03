using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace SSAO
{
    public class CustomSSAORendererFeature : ScriptableRendererFeature
    {
        public enum KernelGeneratorMethod
        {
            [Tooltip("Spherical: Reflects sample vectors using a random vector to reduce banding artifacts.")]
            Spherical,
            [Tooltip("Hemispherical: Rotates sample vectors along the surface tangent space.")]
            Hemispherical
        }

        public enum OcclusionFunctionVersion
        {
            [Tooltip("Heuristic: pointVS against reconstructed depth. Occlusion Test: Binary check with radius and bias.")]
            V1,
            [Tooltip("Slight modification of V1 with smooth attenuation. Uses occlusion bias, power, and scale for softer results.")]
            V2,
            [Tooltip("Heuristic: sampleVS against reconstructed depth. Occlusion Test: Uses full/no occlusion thresholds and a decay curve.")]
            V3
        }
        
        [Serializable]
        public class CustomSSAO_Settings
        {
            public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
            [Header("Materials")] // for now just passing materials from editor
            public Material ssaoMaterial;
            public Material blurMaterial;
            [Header("SSAO General Params")]
            public bool showAO = false;
            public KernelGeneratorMethod kernelMethod = KernelGeneratorMethod.Spherical;
            [Range(0.01f, 5f)] public float radius = 0.5f;
            [Range(8, 128)] public int sampleCount = 32;
            [Header("Occlusion Function Choice")]
            [Tooltip("Select which occlusion function to use for SSAO calculation.")]
            public OcclusionFunctionVersion occlusionFunctionVersion = OcclusionFunctionVersion.V1;
            [Header("SSAO - Occlusion v1 Params")] 
            public float occlusionBiasV1 = 0.025f;
            [Header("SSAO - Occlusion v2 Params")] 
            public float occlusionScale = 1.0f;
            public float occlusionBiasV2 = 0.025f;
            public float occlusionPowerV2 = 2.0f;
            [Header("SSAO - Occlusion v3 Params")]
            public float fullOcclusionThreshold = 0.2f;
            public float noOcclusionThreshold = 0.5f;
            public float occlusionPowerV3 = 2.0f;
            [Header("Gaussian Blur Params")]
            public bool applyBlur = false;
            [Tooltip("Standard deviation (spread) of the blur. Grid size is approx. 3x larger.")]
            [Range(0.1f, 80.0f)]public float blurSpread = 10.0f;
        }
        
        [SerializeField] 
        private CustomSSAO_Settings m_settings;
        private CustomSSAORenderPass m_customSSAOPass;
        
        public override void Create()
        {
            if (m_settings.ssaoMaterial == null)
                return;
            
            m_customSSAOPass = new CustomSSAORenderPass(m_settings);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            // checks
            if(m_customSSAOPass == null)
                return;
            
            // The inputs will get bound as global shader texture properties and can be sampled in the shader using the following:
            // * Depth  - use "SampleSceneDepth" after including "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            // * Normal - use "SampleSceneNormals" after including "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            m_customSSAOPass.ConfigureInput(ScriptableRenderPassInput.Normal | ScriptableRenderPassInput.Depth);
            
            renderer.EnqueuePass(m_customSSAOPass);
        }
    
    }
}
