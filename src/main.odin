package main

import NS  "core:sys/darwin/Foundation"
import CA  "vendor:darwin/QuartzCore"
import "core:fmt"
import "core:time"
import "core:strings"

// Window creation constants
WINDOW_WIDTH  :: 1024
WINDOW_HEIGHT :: 768

// Application state
App_State :: struct {
    window:      ^NS.Window,
    metal_layer: ^CA.MetalLayer,
    renderer:    ^Metal_Renderer,
    editor:      ^Editor,

    running:     bool,
    last_time:   time.Time,
}

g_app: App_State

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

    // Create and configure Metal layer
    metal_layer := CA.MetalLayer_layer()
    CA.MetalLayer_setPixelFormat(metal_layer, .BGRA8Unorm)

    // Set drawable size based on view bounds
    bounds := NS.View_bounds(content_view)
    scale := NS.Window_backingScaleFactor(window)
    drawable_size := NS.Size{
        width = bounds.size.width * scale,
        height = bounds.size.height * scale,
    }
    CA.MetalLayer_setDrawableSize(metal_layer, drawable_size)
    CA.MetalLayer_setFrame(metal_layer, bounds)

    // Set the Metal layer as the view's layer
    NS.View_setLayer(content_view, cast(^NS.Layer)metal_layer)

    g_app.metal_layer = metal_layer

    return window
}

handle_event :: proc(event: ^NS.Event) {
    if g_app.editor == nil do return

    event_type := NS.Event_type(event)

    #partial switch event_type {
    case .KeyDown:
        key_code := NS.Event_keyCode(event)
        characters := NS.Event_characters(event)
        modifier_flags := NS.Event_modifierFlags(event)

        // Handle special keys
        switch key_code {
        case u16(NS.kVK.LeftArrow):
            editor_move_cursor(g_app.editor, 0, .Left, false)
        case u16(NS.kVK.RightArrow):
            editor_move_cursor(g_app.editor, 0, .Right, false)
        case u16(NS.kVK.UpArrow):
            editor_move_cursor(g_app.editor, 0, .Up, false)
        case u16(NS.kVK.DownArrow):
            editor_move_cursor(g_app.editor, 0, .Down, false)
        case u16(NS.kVK.Delete):
            editor_delete_char(g_app.editor, false)
        case u16(NS.kVK.Return):
            editor_insert_text(g_app.editor, "\n")
        case:
            // Insert regular characters
            if characters != nil {
                char_str := characters->odinString()
                if len(char_str) > 0 && char_str[0] >= 32 {  // Printable characters
                    editor_insert_text(g_app.editor, char_str)
                }
            }
        }

        editor_scroll_to_cursor(g_app.editor)

    case .ScrollWheel:
        delta_x, delta_y := NS.Event_scrollingDelta(event)
        g_app.editor.target_scroll.x -= f32(delta_x) * 10
        g_app.editor.target_scroll.y -= f32(delta_y) * 10
    }
}

render_frame :: proc() {
    if g_app.renderer == nil || g_app.editor == nil do return

    dt := time.duration_seconds(time.since(g_app.last_time))
    g_app.last_time = time.now()

    // Update editor state
    editor_update_scroll(g_app.editor, f32(dt))

    // Begin rendering
    renderer_begin_frame(g_app.renderer)

    // Draw editor content
    start_line, end_line := editor_get_visible_lines(g_app.editor)

    y := -g_app.editor.scroll.y
    for line := start_line; line < end_line; line += 1 {
        line_text := buffer_get_line(g_app.editor.buffer, line)
        renderer_draw_text(g_app.renderer, line_text, -g_app.editor.scroll.x, y, {1, 1, 1, 1})
        y += g_app.editor.line_height
    }

    // Draw cursor
    if len(g_app.editor.cursors) > 0 {
        cursor := g_app.editor.cursors[0]
        line, col := buffer_pos_to_line_col(g_app.editor.buffer, cursor.pos)
        cursor_x := f32(col) * g_app.editor.char_width - g_app.editor.scroll.x
        cursor_y := f32(line) * g_app.editor.line_height - g_app.editor.scroll.y

        // Blinking cursor
        if int(time.duration_seconds(time.since(g_app.last_time)) * 2) % 2 == 0 {
            renderer_draw_rect(g_app.renderer, cursor_x, cursor_y, 2, g_app.editor.line_height, {1, 1, 1, 1})
        }
    }

    // End rendering
    renderer_end_frame(g_app.renderer, f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT))
}

main :: proc() {
    // Create shared application instance
    app := NS.Application_sharedApplication()
    NS.Application_setActivationPolicy(app, NS.ActivationPolicy.Regular)

    // Create main window
    g_app.window = create_window()

    // Show window
    NS.Window_makeKeyAndOrderFront(g_app.window, nil)
    NS.Application_activateIgnoringOtherApps(app, NS.YES)

    // Initialize renderer
    g_app.renderer = renderer_init(g_app.metal_layer)

    // Create initial buffer and editor
    buffer := buffer_from_string("Welcome to Arcana Editor!\n\nStart typing to edit...\n")
    g_app.editor = editor_new(buffer)
    g_app.editor.viewport = {0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}

    fmt.println("Arcana Editor started. Press ESC to exit.")

    // Initialize timing
    g_app.last_time = time.now()
    g_app.running = true

    // Custom event loop
    main_loop: for g_app.running {
        process_event(app)
        render_frame()
    }

    fmt.println("Exiting...")
}

process_event :: proc(app: ^NS.Application) {
    // Poll with timeout for ~60 FPS
    event := NS.Application_nextEventMatchingMask(
        app,
        NS.EventMaskAny,
        NS.Date_dateWithTimeIntervalSinceNow(0.016),
        NS.DefaultRunLoopMode,
        NS.YES
    )

    if event != nil {
        event_type := NS.Event_type(event)

        // Check for ESC key to exit
        if event_type == .KeyDown {
            key_code := NS.Event_keyCode(event)
            if key_code == u16(NS.kVK.Escape) {
                g_app.running = false
            }
        }

        // Handle the event
        handle_event(event)

        // Send event to the application for default handling
        NS.Application_sendEvent(app, event)
    }
}
