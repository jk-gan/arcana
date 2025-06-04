package main

import NS  "core:sys/darwin/Foundation"
import CA  "vendor:darwin/QuartzCore"

import "core:fmt"

WINDOW_WIDTH  :: 1024
WINDOW_HEIGHT :: 768

App_Config :: struct {}

App_State :: struct {
    window:      ^NS.Window,
    metal_layer: ^CA.MetalLayer,
    running:     bool,
}

app_state: App_State

create_window :: proc() -> ^NS.Window {
    // Get main screen dimensions
    main_screen := NS.Screen_mainScreen()
    screen_frame := NS.Screen_frame(main_screen)

    // Calculate centered window position
    window_width  := NS.Float(WINDOW_WIDTH)
    window_height := NS.Float(WINDOW_HEIGHT)
    x := (screen_frame.size.width - window_width) / 2
    y := (screen_frame.size.height - window_height) / 2

    // Create window rect
    content_rect := NS.Rect{
        origin = { x, y },
        size = { window_width, window_height },
    }

    // Create window style mask with full size content view
    style_mask := NS.WindowStyleMaskTitled |
                NS.WindowStyleMaskClosable |
                NS.WindowStyleMaskMiniaturizable |
                NS.WindowStyleMaskResizable |
                NS.WindowStyleMaskFullSizeContentView

    // Create window
    window := NS.Window_alloc()
    window = NS.Window_initWithContentRect(
        window,
        content_rect,
        style_mask,
        NS.BackingStoreType.Buffered,
        NS.NO
    )

    // Set window properties
    title := NS.String.alloc()->initWithOdinString("Arcana Editor")
    NS.Window_setTitle(window, title)

    // Make title bar transparent and hide the title
    NS.Window_setTitlebarAppearsTransparent(window, NS.YES)
    NS.Window_setTitleVisibility(window, NS.Window_Title_Visibility.Hidden)

    // Set window appearance
    NS.Window_setOpaque(window, NS.YES)

    // Set background color (dark gray)
    bg_color := NS.Color_colorWithSRGBRed(0.15, 0.15, 0.15, 1.0)
    NS.Window_setBackgroundColor(window, bg_color)

    // Get the content view and enable layer backing
    content_view := NS.Window_contentView(window)
    NS.View_setWantsLayer(content_view, NS.YES)

    metal_layer := CA.MetalLayer_layer()
    CA.MetalLayer_setPixelFormat(metal_layer, .BGRA8Unorm)

    bounds := NS.View_bounds(content_view)
    scale := NS.Window_backingScaleFactor(window)
    drawable_size := NS.Size {
        width = bounds.size.width * scale,
        height = bounds.size.height * scale,
    }
    CA.MetalLayer_setDrawableSize(metal_layer, drawable_size)
    CA.MetalLayer_setFrame(metal_layer, bounds)

    NS.View_setLayer(content_view, cast(^NS.Layer)metal_layer)

    app_state.metal_layer = metal_layer

    return window
}

handle_event :: proc(event: ^NS.Event) {
    event_type := NS.Event_type(event)

    #partial switch event_type {
    case .KeyDown:
        key_code := NS.Event_keyCode(event)
        characters := NS.Event_characters(event)
        modifier_flags := NS.Event_modifierFlags(event)

        // Convert NSString to Odin string for printing
        if characters != nil {
            char_str := characters->odinString()
            fmt.printf("Key Down: code=%d, char='%s', modifiers=%v\n",
                      key_code, char_str, modifier_flags)
        }

    case .KeyUp:
        key_code := NS.Event_keyCode(event)
        fmt.printf("Key Up: code=%d\n", key_code)

    case .LeftMouseDown:
        location := NS.Event_locationInWindow(event)
        fmt.printf("Left Mouse Down at: %.2f, %.2f\n", location.x, location.y)

    case .LeftMouseUp:
        location := NS.Event_locationInWindow(event)
        fmt.printf("Left Mouse Up at: %.2f, %.2f\n", location.x, location.y)

    // case .RightMouseDown:
    // case .RightMouseUp:
    // case .LeftMouseDragged:
	// case .RightMouseDragged:

    case .MouseMoved:
        location := NS.Event_locationInWindow(event)
        fmt.printf("Mouse Moved to: %.2f, %.2f\n", location.x, location.y)

    case .ScrollWheel:
        delta_x, delta_y := NS.Event_scrollingDelta(event)
        if delta_x != 0 || delta_y != 0 {
            fmt.printf("Scroll: dx=%.2f, dy=%.2f\n", delta_x, delta_y)
        }
    }
}

main :: proc() {
    // Create shared application instance
    app := NS.Application_sharedApplication()
    NS.Application_setActivationPolicy(app, NS.ActivationPolicy.Regular)

    // Create main window
    app_state.window = create_window()
    if app_state.window == nil {
        fmt.panicf("Failed to create window")
    }

    // Show window
    NS.Window_makeKeyAndOrderFront(app_state.window, nil)
    NS.Application_activateIgnoringOtherApps(app, NS.YES)

    fmt.println("Window created successfully. Press ESC to exit.")

    app_state.running = true
    main_loop: for app_state.running {
        process_event(app)
        render(app)
    }

    fmt.println("Exiting...")
}

process_event :: proc(app: ^NS.Application) {
    event := NS.Application_nextEventMatchingMask(
        app,
        NS.EventMaskAny,
        NS.Date_distantFuture(),
        NS.DefaultRunLoopMode,
        NS.YES
    )

    if event != nil {
        event_type := NS.Event_type(event)

        // Check for ESC key to exit
        if event_type == .KeyDown {
            key_code := NS.Event_keyCode(event)
            if key_code == u16(NS.kVK.Escape) {
                app_state.running = false
            }
        }

        // Handle the event
        handle_event(event)

        // Send event to the application for default handling
        NS.Application_sendEvent(app, event)
    }
}

render :: proc(app: ^NS.Application) {
    NS.Application_updateWindows(app)
}
