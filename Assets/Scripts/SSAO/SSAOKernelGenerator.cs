using System;
using UnityEngine;
using Random = UnityEngine.Random;

namespace SSAO
{
    public static class SSAOKernelGenerator
    {
        private static Vector4[] _kernel;
        private const int MaxKernelSize = 128;
        private static int _currentKernelSize = 0;
        
        public static Vector4[] GetSSAOKernel(int i_sampleCount, CustomSSAORendererFeature.KernelGeneratorMethod i_method)
        {
            if (_kernel != null && _currentKernelSize == i_sampleCount) return _kernel;

            _kernel ??= new Vector4[MaxKernelSize];
            
            _currentKernelSize = i_sampleCount;

            switch (i_method)
            {
                case CustomSSAORendererFeature.KernelGeneratorMethod.Spherical:
                    GenerateSSAOKernel_Spherical(i_sampleCount);
                    break;
                case CustomSSAORendererFeature.KernelGeneratorMethod.Hemispherical:
                    GenerateSSAOKernel_Hemisphere(i_sampleCount);
                    break;
                default:
                    throw new ArgumentOutOfRangeException(nameof(i_method), i_method, null);
            }
            
            return _kernel;
        }
        
        private static float CustomLerp(float a, float b, float f)
        {
            return a + f * (b - a);
        }
        
        private static void GenerateSSAOKernel_Hemisphere(int sampleCount)
        {
            // fill the kernel with random generated vectors
            for (int i = 0; i < sampleCount; i++)
            {
                float xSample = Random.Range(0f, 1f) * 2 - 1;
                float ySample = Random.Range(0f, 1f) * 2 - 1;
                float zSample = Random.Range(0f, 1f); // z will point out the surface, like a normal vector
                Vector3 sample = new Vector3(xSample, ySample, zSample);
                
                // Uniform distribution of sample points may result in a flat look
                // Also being too far from the main surface is a waste of performance
                sample =  sample.normalized;
                // bias toward the center
                sample *= Random.Range(0.0f, 1.0f);

                // scale samples to concentrate more toward center
                float scale = (float) i / sampleCount;
                // quadratic distribution
                scale = CustomLerp(0.1f, 1.0f, scale * scale);
                sample *= scale;

                Vector4 hSample = new Vector4(sample.x, sample.y, sample.z, 1);
                _kernel[i] = hSample;
                
            }
            
        }
        
        private static void GenerateSSAOKernel_Spherical(int sampleCount)
        {
            // fill the kernel with random generated vectors in a whole sphere
            for (int i = 0; i < sampleCount; i++)
            {
                float xSample = Random.Range(0f, 1f) * 2 - 1;
                float ySample = Random.Range(0f, 1f) * 2 - 1;
                float zSample = Random.Range(0f, 1f) * 2 - 1;
                Vector3 sample = new Vector3(xSample, ySample, zSample);
                
                sample =  sample.normalized;

                Vector4 hSample = new Vector4(sample.x, sample.y, sample.z, 1);
                _kernel[i] = hSample;
            }
            
        }
    
    }
}
