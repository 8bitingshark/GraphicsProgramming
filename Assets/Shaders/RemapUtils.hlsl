// RemapUtils.hlsl

#ifndef REMAP_UTILS_H
#define REMAP_UTILS_H

// Remap a Single float
inline float RemapValue(
    float value,
    float inMin,
    float inMax,
    float outMin,
    float outMax,
    bool doClamp    // if true, clamp the result at range [outMin,outMax]
)
{
    // map to 0→1
    float t = (value - inMin) / (inMax - inMin);
    // map to outputRange
    float result = lerp(outMin, outMax, t);
    if (doClamp)
        result = saturate((result - outMin) / (outMax - outMin)) * (outMax - outMin) + outMin;
    return result;
}

inline float2 RemapValue(float2 v, float2 inMin, float2 inMax, float2 outMin, float2 outMax, bool doClamp)
{
    return float2(
        RemapValue(v.x, inMin.x, inMax.x, outMin.x, outMax.x, doClamp),
        RemapValue(v.y, inMin.y, inMax.y, outMin.y, outMax.y, doClamp)
    );
}

inline float3 RemapValue(float3 v, float3 inMin, float3 inMax, float3 outMin, float3 outMax, bool doClamp)
{
    return float3(
        RemapValue(v.x, inMin.x, inMax.x, outMin.x, outMax.x, doClamp),
        RemapValue(v.y, inMin.y, inMax.y, outMin.y, outMax.y, doClamp),
        RemapValue(v.z, inMin.z, inMax.z, outMin.z, outMax.z, doClamp)
    );
}

inline float4 RemapValue(float4 v, float4 inMin, float4 inMax, float4 outMin, float4 outMax, bool doClamp)
{
    return float4(
        RemapValue(v.x, inMin.x, inMax.x, outMin.x, outMax.x, doClamp),
        RemapValue(v.y, inMin.y, inMax.y, outMin.y, outMax.y, doClamp),
        RemapValue(v.z, inMin.z, inMax.z, outMin.z, outMax.z, doClamp),
        RemapValue(v.w, inMin.w, inMax.w, outMin.w, outMax.w, doClamp)
    );
}

#endif
