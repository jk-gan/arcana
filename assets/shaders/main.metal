#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vertex_main(device const float2* vertex_array [[buffer(0)]],
                              uint vid [[vertex_id]]) {
    VertexOut out;
    out.position = float4(vertex_array[vid], 0.0, 1.0);
    return out;
}

fragment float4 fragment_main() {
    return float4(1.0, 0.5, 0.0, 1.0); // Orange
}
