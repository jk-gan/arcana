package main

import "core:fmt"

import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"
import NS "core:sys/darwin/Foundation"

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

    r.library = r.device->newDefaultLibrary()
    if r.library == nil {
        fmt.eprintln("Failed to create Metal library. Make sure default.metallib is in the executable directory.")
        return false
    }

    vertex_fn := r.library->newFunctionWithName(NS.String.alloc()->initWithOdinString("vertex_main"))
    if vertex_fn == nil {
        fmt.eprintln("Failed to find vertex shader function")
        return false
    }
    defer vertex_fn->release()

    fragment_fn := r.library->newFunctionWithName(NS.String.alloc()->initWithOdinString("fragment_main"))
    if fragment_fn == nil {
        fmt.eprintln("Failed to find fragment shader function")
        return false
    }
    defer fragment_fn->release()

    pipeline_descriptor := MTL.RenderPipelineDescriptor.alloc()->init()
    defer pipeline_descriptor->release()

    pipeline_descriptor->setVertexFunction(vertex_fn)
    pipeline_descriptor->setFragmentFunction(fragment_fn)
    pipeline_descriptor->colorAttachments()->object(0)->setPixelFormat(metal_layer->pixelFormat())

    pipeline_state, err := r.device->newRenderPipelineStateWithDescriptor(pipeline_descriptor)
    if err != nil {
        fmt.eprintf("Failed to create render pipeline state: %v\n", err)
        return false
    }
    r.render_pipeline = pipeline_state

    triangle_vertices := [?]f32{
         0.0,  0.5,
        -0.5, -0.5,
         0.5, -0.5,
    }

    vertex_data_bytes := ([^]u8)(&triangle_vertices[0])[:size_of(triangle_vertices)]

    r.vertex_buffer = r.device->newBufferWithBytes(
        vertex_data_bytes,
        {},
    )
    if r.vertex_buffer == nil {
        fmt.eprintln("Failed to create vertex buffer")
        return false
    }

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

    render_encoder->setRenderPipelineState(r.render_pipeline)
    render_encoder->setVertexBuffer(r.vertex_buffer, 0, 0)
    render_encoder->drawPrimitives(.Triangle, 0, 3)

    render_encoder->endEncoding()

    command_buffer->presentDrawable(drawable)
    command_buffer->commit()
}
