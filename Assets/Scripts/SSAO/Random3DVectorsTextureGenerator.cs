using System.IO;
using UnityEditor;
using UnityEngine;

namespace SSAO
{
    public static class Random3DVectorsTextureGenerator
    {
        [MenuItem("Tools/Generate Random Vectors Texture for SSAO")]
        public static void GenerateRandom2DVectorsTexture()
        {
            int size = 4;

            Texture2D tex = new Texture2D(size, size, TextureFormat.RGBAFloat, false, true)
            {
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Repeat
            };

            for (int x = 0;x < size; ++x)
            {
                for (int y = 0; y < size; ++y)
                {
                    float xSample = Random.Range(0f, 1f) * 2 - 1;
                    float ySample = Random.Range(0f, 1f) * 2 - 1;
                    float zSample = 0.0f;
                    Vector3 sample = new Vector3(xSample, ySample, zSample);
                    
                    sample =  sample.normalized;
                    sample *= 0.5f;
                    
                    // if the random vector is a zero vector, the tbn built convert the sample into a scaled vector along the normal of the surface
                    tex.SetPixel(x, y, new Color(sample.x + 0.5f, sample.y + 0.5f, sample.z + 0.5f)); 
                }
            }
            
            tex.Apply();
            byte[] pngData = tex.EncodeToPNG();
            string path = $"Assets/ssao2DRot_{size}x{size}_Texture.png";
            File.WriteAllBytes(path, pngData);
            AssetDatabase.Refresh();
            Debug.Log($"ssaoRot {size}x{size} texture saved in: {path}");
        }
    }
}
