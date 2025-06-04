package main

import "core:fmt"

import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

Renderer :: struct {
    device:          ^MTL.Device,
    command_queue:   ^MTL.CommandQueue,
    library:         ^MTL.Library,

    render_pipeline: ^MTL.RenderPipelineState,

    vertex_buffer:   ^MTL.Buffer,
    uniform_buffer:  ^MTL.Buffer,
}

renderer_init :: proc(r: ^Renderer, metal_layer: ^CA.MetalLayer) -> bool {
    r.device = MTL.CreateSystemDefaultDevice()
    if r.device == nil {
        fmt.eprintln("Failed to create Metal device")
        return false
    }

    // Tell the layer which GPU to use
    CA.MetalLayer_setDevice(metal_layer, r.device)

    // BGRA8Unorm means:
    // - B,G,R,A = color channel order
    // - 8 = 8 bits per channel
    // - Unorm = Unsigned normalized (0-255 maps to 0.0-1.0)
    CA.MetalLayer_setPixelFormat(metal_layer, .BGRA8Unorm)

    r.command_queue = MTL.Device_newCommandQueue(r.device)
    if r.command_queue == nil {
        fmt.eprintln("Failed to create Metal command queue")
        return false
    }

    r.library = MTL.Device_newDefaultLibrary(r.device)
    if r.library == nil {
        fmt.eprintln("Failed to create Metal library")
    }

    return true
}

renderer_draw_frame :: proc(r: ^Renderer, metal_layer: ^CA.MetalLayer) {
    // drawable is the texture we can render to
    drawable := CA.MetalLayer_nextDrawable(metal_layer)
    if drawable == nil do return // No drawable available, skip frame

    // command buffer is a list of GPU commands to execute
    command_buffer := MTL.CommandQueue_commandBuffer(r.command_queue)
}