using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

namespace SSAO
{
    public class CustomSSAORenderPass : ScriptableRenderPass
    {
        // Shader property IDs
        private static readonly int CustomSsaotexId = Shader.PropertyToID("_CustomSsaoTex");
        private static readonly int RadiusID        = Shader.PropertyToID("_Radius");
        private static readonly int SampleCountID   = Shader.PropertyToID("_SampleCount");
        private static readonly int KernelID        = Shader.PropertyToID("_SSAOKernel");
        private static readonly int BlurSpreadID    = Shader.PropertyToID("_Spread");
        private static readonly int BlurGridSizeID  = Shader.PropertyToID("_GridSize");
        // v1
        private static readonly int OcclBiasV1ID     = Shader.PropertyToID("_OcclusionBiasV1");
        // v2
        private static readonly int OcclScaleID     = Shader.PropertyToID("_OcclusionScale");
        private static readonly int OcclBiasV2ID    = Shader.PropertyToID("_OcclusionBiasV2");
        private static readonly int OcclPowerV2ID   = Shader.PropertyToID("_OcclusionPowerV2");
        // v3
        private static readonly int FullOcclThID    = Shader.PropertyToID("_FullOcclusionThreshold");
        private static readonly int NoOcclThID      = Shader.PropertyToID("_NoOcclusionThreshold");
        private static readonly int OcclPowerV3ID   = Shader.PropertyToID("_OcclusionPowerV3");
        
        // const strings
        private const string KeySphericalMethod = "_SPHERICAL_METHOD";
        private const string KeyOcclusionFunctionV1 = "_OCCLUSION_V1";
        private const string KeyOcclusionFunctionV2 = "_OCCLUSION_V2";
        private const string KeyOcclusionFunctionV3 = "_OCCLUSION_V3";
        
        // The property block used to set additional properties for the material
        private static MaterialPropertyBlock s_SharedPropertyBlock = new();
        
        // fields
        private CustomSSAORendererFeature.CustomSSAO_Settings m_passSettings;
        private Material m_ssaoMaterial;
        private Material m_blurMaterial;
        
        // profilers
        private ProfilingSampler m_profSSAO      = new("Custom SSAO");
        private ProfilingSampler m_profBlurV     = new("Custom SSAO Blur V");
        private ProfilingSampler m_profBlurH     = new("Custom SSAO Blur H");
        
        // CTOR
        public CustomSSAORenderPass(CustomSSAORendererFeature.CustomSSAO_Settings in_passSettings)
        {
            m_passSettings = in_passSettings;
            renderPassEvent = m_passSettings.renderPassEvent;
            
            // Set materials
            if (m_ssaoMaterial == null) m_ssaoMaterial = m_passSettings.ssaoMaterial;
            if (m_blurMaterial == null) m_blurMaterial = m_passSettings.blurMaterial;
            
            if(m_ssaoMaterial == null) Debug.LogError("CustomSSAORenderPass: m_ssaoMaterial == null");
        }
        
        // DATA for PASSES
        public class SsaoFrameData : ContextItem {
            public TextureHandle AOTexture;
            public int Width;
            public int Height;

            public override void Reset()
            {
                AOTexture = TextureHandle.nullHandle;
            }
        }  
        private class SsaoPassData
        {
            public Material SsaoMaterial;
            public float Radius;
            public CustomSSAORendererFeature.KernelGeneratorMethod KernelGeneratorMethod;
            public CustomSSAORendererFeature.OcclusionFunctionVersion OcclusionFunctionVersion;
            public int SampleCount;
            // v1
            public float OcclusionBiasV1;
            // v2
            public float OcclusionScale;
            public float OcclusionBiasV2;
            public float OcclusionPowerV2;
            // v3
            public float FullOcclusionThreshold;
            public float NoOcclusionThreshold;
            public float OcclusionPowerV3;
            
        }
        private class SsaoBlurPassData
        {
            public Material BlurMaterial;
            public TextureHandle SourceTexture;
            public float BlurSpread;
            public int BlurGridSize;
            public bool IsHorizontal;
        }
        
        private class PublishAoPassData
        {
            public TextureHandle AoTexture;
        }
        
        private static void ExecuteCustomSsaoPass(SsaoPassData data, RasterGraphContext ctx)
        {
            var cmd = ctx.cmd;
            
            s_SharedPropertyBlock.Clear();
            
            // Spherical or hemispherical method
            if (data.KernelGeneratorMethod == CustomSSAORendererFeature.KernelGeneratorMethod.Spherical)
            {
                data.SsaoMaterial.EnableKeyword(KeySphericalMethod);
            }
            else
            {
                data.SsaoMaterial.DisableKeyword(KeySphericalMethod);
            }
            
            // Occlusion Function choice
            data.SsaoMaterial.DisableKeyword(KeyOcclusionFunctionV1);
            data.SsaoMaterial.DisableKeyword(KeyOcclusionFunctionV2);
            data.SsaoMaterial.DisableKeyword(KeyOcclusionFunctionV3);

            switch (data.OcclusionFunctionVersion)
            {
                case CustomSSAORendererFeature.OcclusionFunctionVersion.V2:
                    data.SsaoMaterial.EnableKeyword(KeyOcclusionFunctionV2);
                    break;
                case CustomSSAORendererFeature.OcclusionFunctionVersion.V3:
                    data.SsaoMaterial.EnableKeyword(KeyOcclusionFunctionV3);
                    break;
                case CustomSSAORendererFeature.OcclusionFunctionVersion.V1: // fallback
                default: 
                    data.SsaoMaterial.EnableKeyword(KeyOcclusionFunctionV1);
                    break;
            }
            
            s_SharedPropertyBlock.SetFloat(RadiusID, data.Radius);
            s_SharedPropertyBlock.SetInt(SampleCountID, data.SampleCount);
            // v1
            s_SharedPropertyBlock.SetFloat(OcclBiasV1ID, data.OcclusionBiasV1);
            // v2
            s_SharedPropertyBlock.SetFloat(OcclScaleID, data.OcclusionScale);
            s_SharedPropertyBlock.SetFloat(OcclBiasV2ID,  data.OcclusionBiasV2);
            s_SharedPropertyBlock.SetFloat(OcclPowerV2ID, data.OcclusionPowerV2);
            // v3
            s_SharedPropertyBlock.SetFloat(FullOcclThID, data.FullOcclusionThreshold);
            s_SharedPropertyBlock.SetFloat(NoOcclThID, data.NoOcclusionThreshold);
            s_SharedPropertyBlock.SetFloat(OcclPowerV3ID, data.OcclusionPowerV3);
            
            // kernel
            s_SharedPropertyBlock.SetVectorArray(KernelID, SSAOKernelGenerator.GetSSAOKernel(data.SampleCount, data.KernelGeneratorMethod));
            
            // draw call
            cmd.DrawProcedural(Matrix4x4.identity, data.SsaoMaterial, 0, MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);

        }
        
        private static void ExecuteBlurPass(SsaoBlurPassData data, RasterGraphContext ctx)
        {
            var cmd = ctx.cmd;
            
            data.BlurMaterial.SetFloat(BlurSpreadID, data.BlurSpread);
            data.BlurMaterial.SetInt(BlurGridSizeID, data.BlurGridSize);
            Blitter.BlitTexture(cmd, data.SourceTexture, Vector2.one, data.BlurMaterial, data.IsHorizontal ? 0 : 1);
        }
        
        public override void RecordRenderGraph(RenderGraph renderGraph,
            ContextContainer frameData)
        {
            if (!m_passSettings.showAO || m_ssaoMaterial == null)
                return;
            
            // Get data from the URP
            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            UniversalCameraData cameraData     = frameData.Get<UniversalCameraData>();
            
            TextureDesc camDesc = renderGraph.GetTextureDesc(resourceData.cameraColor);
            
            // The following line ensures that the render pass doesn't blit from the back buffer.
            if (resourceData.isActiveTargetBackBuffer)
                return;
            
            // get dimension of the render target
            int width = camDesc.width;          
            int height = camDesc.height;

            //----------------------------------------------------------------------------------------------
            // Create Texture
            
            TextureDesc aoTexDesc = new TextureDesc(width, height)
            {
                colorFormat = UnityEngine.Experimental.Rendering.GraphicsFormat.R8G8B8A8_UNorm,
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp,
                name = "CustomSSAO_AO",
                clearBuffer = false
            };
            
            // Create AO texture
            TextureHandle aoTex = renderGraph.CreateTexture(aoTexDesc);
        
            //----------------------------------------------------------------------------------------------
            // CUSTOM SSAO pass
            
            using (var builder = renderGraph.AddRasterRenderPass<SsaoPassData>("Custom SSAO", out var passData, m_profSSAO))
            {
                // fill the data
                passData.SsaoMaterial             = m_ssaoMaterial;
                passData.Radius                   = m_passSettings.radius;
                passData.SampleCount              = m_passSettings.sampleCount;
                passData.KernelGeneratorMethod    = m_passSettings.kernelMethod;
                passData.OcclusionFunctionVersion = m_passSettings.occlusionFunctionVersion;
                // v1
                passData.OcclusionBiasV1          = m_passSettings.occlusionBiasV1;
                // v2
                passData.OcclusionScale           = m_passSettings.occlusionScale;
                passData.OcclusionBiasV2          = m_passSettings.occlusionBiasV2;
                passData.OcclusionPowerV2         = m_passSettings.occlusionPowerV2;
                // v3
                passData.FullOcclusionThreshold   = m_passSettings.fullOcclusionThreshold;
                passData.NoOcclusionThreshold     = m_passSettings.noOcclusionThreshold;
                passData.OcclusionPowerV3         = m_passSettings.occlusionPowerV3;
                
                builder.UseTexture(resourceData.cameraDepth, AccessFlags.Read);
                builder.UseTexture(resourceData.cameraNormalsTexture, AccessFlags.Read);
                
                // SetRenderAttachment: use the texture as an RT attachment.
                // The index that the shader will use to access this texture.
                // If you know you will write the full screen the AccessFlags.WriteAll should be used instead as it will give better performance.
                builder.SetRenderAttachment(aoTex, 0, AccessFlags.WriteAll);
                builder.AllowPassCulling(false);
                
                builder.SetRenderFunc((SsaoPassData data, RasterGraphContext ctx) => ExecuteCustomSsaoPass(data, ctx));
            }
            
            //----------------------------------------------------------------------------------------------
            // Blur (optional)
            
            if (m_passSettings.applyBlur && m_blurMaterial != null)
            {
                // Create the grid size of the gaussian blur
                // A grid size of about 6σ works well, then round up to the next pixel so the grid has a center pixel.
                int gridSize = Mathf.CeilToInt(m_passSettings.blurSpread * 6.0f);
                if (gridSize % 2 == 0)
                {
                    gridSize++;
                }
                
                // - HORIZONTAL -
                TextureDesc aoBlurredDesc = aoTex.GetDescriptor(renderGraph);
                aoBlurredDesc.name = "CustomSSAO_Blur";
                TextureHandle aoTexHorizontalBlur = renderGraph.CreateTexture(aoBlurredDesc);

                using (var builder = renderGraph.AddRasterRenderPass<SsaoBlurPassData>("Custom SSAO Blur H", out var passData, m_profBlurH))
                {
                    builder.UseTexture(aoTex, AccessFlags.Read);
                    passData.SourceTexture = aoTex;
                    passData.BlurMaterial  = m_blurMaterial;
                    passData.BlurSpread    = m_passSettings.blurSpread;
                    passData.BlurGridSize  = gridSize;
                    passData.IsHorizontal  = true;
                    
                    builder.SetRenderAttachment(aoTexHorizontalBlur, 0, AccessFlags.WriteAll);
                    builder.AllowPassCulling(false);
                    
                    builder.SetRenderFunc((SsaoBlurPassData data, RasterGraphContext ctx) => ExecuteBlurPass(data, ctx));
                }

                // - VERTICAL -
                using (var builder = renderGraph.AddRasterRenderPass<SsaoBlurPassData>("Custom SSAO Blur V", out var passData, m_profBlurV))
                {
                    builder.UseTexture(aoTexHorizontalBlur, AccessFlags.Read);
                    passData.SourceTexture = aoTexHorizontalBlur;
                    passData.BlurMaterial  = m_blurMaterial;
                    passData.BlurSpread    = m_passSettings.blurSpread;
                    passData.BlurGridSize  = gridSize;
                    passData.IsHorizontal  = false;
                    
                    builder.SetRenderAttachment(aoTex, 0, AccessFlags.WriteAll);
                    builder.AllowPassCulling(false);
                    
                    builder.SetRenderFunc((SsaoBlurPassData data, RasterGraphContext ctx) => ExecuteBlurPass(data, ctx));
                }
                
            }
            
            // Publish
            /*
            using (var builder = renderGraph.AddRasterRenderPass<PublishAoPassData>("Publish AO Global", out var pubData, m_profSSAO))
            {
                pubData.AoTexture = aoTex;
                builder.UseTexture(pubData.AoTexture, AccessFlags.Read);
                builder.SetGlobalTextureAfterPass(aoTex, CustomSsaotexId);
                builder.AllowPassCulling(false);

                builder.SetRenderFunc((PublishAoPassData data, RasterGraphContext ctx) =>
                {
                });
            }*/
            
            // For those who come after -------------------------------------------------
            /*
            var ssaoFd = frameData.GetOrCreate<SsaoFrameData>();
            ssaoFd.AOTexture = aoTex;
            ssaoFd.Width = width;
            ssaoFd.Height = height; */
            
            if (RenderGraphUtils.CanAddCopyPassMSAA())
            {
                renderGraph.AddCopyPass(aoTex, resourceData.activeColorTexture);
            }
        }
    }
}
