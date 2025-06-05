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
    metal_layer->setDevice(r.device)

    // BGRA8Unorm means:
    // - B,G,R,A = color channel order
    // - 8 = 8 bits per channel
    // - Unorm = Unsigned normalized (0-255 maps to 0.0-1.0)
    metal_layer->setPixelFormat(.BGRA8Unorm)

    r.command_queue = r.device->newCommandQueue()
    if r.command_queue == nil {
        fmt.eprintln("Failed to create Metal command queue")
        return false
    }

    // r.library = r.device->newDefaultLibrary()
    // if r.library == nil {
    //     fmt.eprintln("Failed to create Metal library")
    //     return false
    // }

    return true
}

renderer_draw_frame :: proc(r: ^Renderer, metal_layer: ^CA.MetalLayer) {
    // drawable is the texture we can render to
    drawable := metal_layer->nextDrawable()
    if drawable == nil do return // No drawable available, skip frame
    defer drawable->release()

    pass := MTL.RenderPassDescriptor.renderPassDescriptor()
    defer pass->release()

    color_attachment := pass->colorAttachments()->object(0)
    assert(color_attachment != nil)
    color_attachment->setClearColor(MTL.ClearColor{ 0.25, 0.5, 1.0, 1.0 })
    color_attachment->setLoadAction(.Clear)
    color_attachment->setStoreAction(.Store)
    color_attachment->setTexture(drawable->texture())

    // command buffer is a list of GPU commands to execute
    command_buffer := r.command_queue->commandBuffer()
    defer command_buffer->release()

    render_encoder := command_buffer->renderCommandEncoderWithDescriptor(pass)
    defer render_encoder->release()

    render_encoder->endEncoding()

    command_buffer->presentDrawable(drawable)
    command_buffer->commit()
}
