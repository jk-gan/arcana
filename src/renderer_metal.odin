package main

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"
import "core:mem"
import "core:math/linalg"

// Simplified Metal renderer for initial testing
Metal_Renderer :: struct {
    device: ^MTL.Device,
    command_queue: ^MTL.CommandQueue,
    layer: ^CA.MetalLayer,
}

renderer_init :: proc(layer: ^CA.MetalLayer) -> ^Metal_Renderer {
    renderer := new(Metal_Renderer)

    // Get the default Metal device
    renderer.device = MTL.CreateSystemDefaultDevice()
    if renderer.device == nil {
        return nil
    }

    renderer.command_queue = renderer.device->newCommandQueue()
    renderer.layer = layer

    // Configure layer
    CA.MetalLayer_setDevice(layer, renderer.device)

    return renderer
}

renderer_begin_frame :: proc(renderer: ^Metal_Renderer) {
    // For now, just clear
}

renderer_draw_text :: proc(renderer: ^Metal_Renderer, text: string, x, y: f32, color: [4]f32) {
    // Placeholder - will implement proper text rendering later
}

renderer_draw_rect :: proc(renderer: ^Metal_Renderer, x, y, w, h: f32, color: [4]f32) {
    // Placeholder - will implement proper rect rendering later
}

renderer_end_frame :: proc(renderer: ^Metal_Renderer, viewport_width, viewport_height: f32) {
    drawable := CA.MetalLayer_nextDrawable(renderer.layer)
    if drawable == nil do return

    // Create command buffer
    command_buffer := renderer.command_queue->commandBuffer()
    if command_buffer == nil do return

    // Create render pass descriptor
    pass_desc := MTL.RenderPassDescriptor.alloc()->init()
    defer pass_desc->release()

    // Configure color attachment
    color_attachment := pass_desc->colorAttachments()->object(0)
    color_attachment->setTexture(CA.MetalDrawable_texture(drawable))
    color_attachment->setLoadAction(.Clear)
    color_attachment->setClearColor(MTL.ClearColor{0.15, 0.15, 0.15, 1.0})
    color_attachment->setStoreAction(.Store)

    // Create render encoder
    encoder := command_buffer->renderCommandEncoderWithDescriptor(pass_desc)
    if encoder != nil {
        // For now, just clear the screen
        encoder->endEncoding()
    }

    // Present drawable
    command_buffer->presentDrawable(drawable)
    command_buffer->commit()
}
