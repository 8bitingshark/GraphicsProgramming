using UnityEditor;
using UnityEngine;

namespace SSAO
{
    public class RotTexturePostprocessor : AssetPostprocessor
    {
        private void OnPreprocessTexture()
        {
            if (!assetPath.Contains("ssao2DRot_4x4_Texture.png"))
                return;

            var ti = (TextureImporter)assetImporter;
            ti.textureType = TextureImporterType.Default;
            ti.sRGBTexture = false;
            ti.isReadable = true;
            ti.mipmapEnabled = false;
            ti.filterMode = FilterMode.Point;
            ti.wrapMode = TextureWrapMode.Repeat;

            ti.textureCompression = TextureImporterCompression.Uncompressed;

            var settings = ti.GetDefaultPlatformTextureSettings();
            settings.overridden = true;
            settings.format = TextureImporterFormat.RGBAFloat;
            ti.SetPlatformTextureSettings(settings);
        }
    }
}