//
//  Shaders.metal
//  Mandelbrot
//
//  Created by Roy Sianez on 12/8/22.
//

#include <metal_stdlib>
using namespace metal;

struct v_out {
    float4 pos [[position]];
};

v_out vertex v_main(uint vid [[vertex_id]],
                    device const float3* vs [[buffer(0)]])
{
    v_out o;
    o.pos = float4(vs[vid], 1.0);
    return o;
}



#define float3FromHL(h, l) (abs(sin(float3((h) - 0.5000, (h) + 0.1666, (h) - 0.1666) * M_PI_F))  \
                                * (1 - abs((l)*2 - 1))                                           \
                                + (l < 0.5 ? 0 : 1) * abs((l)*2 - 1))

#define float3FromRI(r, i) float3FromHL(1 - atan2((i), (r)) / M_PI_F / 2,    \
                                        tanh(x0 * x0 + y0 * y0) * 0.95 + 0.05)

#define pow_real(r, i, p) (pow((r) * (r) + (i) * (i), (p) * 0.5) * cos((p) * atan2((i), (r))))
#define pow_imag(r, i, p) (pow((r) * (r) + (i) * (i), (p) * 0.5) * sin((p) * atan2((i), (r))))



struct f_params {
    uint32_t iters;
    float partialSquare;
    float partialAdd;
    float power;
    float addition;
};



constant float limit = 100000000;

float4 fragment f_main(             v_out      in       [[stage_in]],
                       device const float2&    size     [[buffer(0)]],
                       device const float*     viewport [[buffer(1)]],
                       device const f_params&  params   [[buffer(2)]])
{
    float x0 = (in.pos.x / size.x * 2 - 1) / viewport[0] - viewport[1];
    float y0 = ((in.pos.y / size.y * 2 - 1) / viewport[0] - viewport[2]) * (size.y / size.x);
    
    float x = x0;
    float y = y0;
    float tempX = x;
    
    for (uint32_t i = 0; i < params.iters; i++) {
        tempX = pow_real(x, y, params.power) + x0 * params.addition;
        y     = pow_imag(x, y, params.power) + y0 * params.addition;
        x = tempX;
        
        if (!(x < limit && y < limit && x > -limit && y > -limit)) return float4(1.0);
    }
    
    // partial square
    float p = params.partialSquare * (params.power - 1) + 1;
    tempX = pow_real(x, y, p);
    y     = pow_imag(x, y, p);
    x = tempX;
    
    // partial add
    x += x0 * params.partialAdd * params.addition;
    y += y0 * params.partialAdd * params.addition;
    
    if (!(x < limit && y < limit && x > -limit && y > -limit)) return float4(1.0);
    
    return float4(float3FromRI(x, y), 1.0);
}
