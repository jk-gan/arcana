package main

import "core:math"

Editor :: struct {
    buffer: ^Buffer,
    
    // Cursor management
    cursors: [dynamic]Cursor,
    primary_cursor_idx: int,
    
    // View state
    viewport: Viewport,
    scroll: Vec2,
    target_scroll: Vec2,  // For smooth scrolling
    
    // Display settings
    line_height: f32,
    char_width: f32,
    font_size: f32,
    
    // Selection
    selection_active: bool,
}

Cursor :: struct {
    pos: int,                  // Byte position in buffer
    selection_anchor: int,     // Start of selection (if any)
    preferred_column: int,     // For vertical movement
}

Viewport :: struct {
    x, y, width, height: f32,
}

Vec2 :: [2]f32

editor_new :: proc(buffer: ^Buffer) -> ^Editor {
    editor := new(Editor)
    editor.buffer = buffer
    
    // Add primary cursor
    append(&editor.cursors, Cursor{pos = 0, selection_anchor = -1})
    
    // Default display settings
    editor.font_size = 14
    editor.line_height = editor.font_size * 1.5
    editor.char_width = editor.font_size * 0.6  // Approximation
    
    return editor
}

editor_move_cursor :: proc(editor: ^Editor, cursor_idx: int, direction: Movement_Direction, extend_selection: bool) {
    if cursor_idx >= len(editor.cursors) do return
    
    cursor := &editor.cursors[cursor_idx]
    old_pos := cursor.pos
    
    switch direction {
    case .Left:
        if cursor.pos > 0 do cursor.pos -= 1
        
    case .Right:
        if cursor.pos < len(editor.buffer.content) do cursor.pos += 1
        
    case .Up:
        line, col := buffer_pos_to_line_col(editor.buffer, cursor.pos)
        if line > 0 {
            new_pos := buffer_line_col_to_pos(editor.buffer, line - 1, cursor.preferred_column)
            cursor.pos = new_pos
        }
        
    case .Down:
        line, col := buffer_pos_to_line_col(editor.buffer, cursor.pos)
        if line < buffer_get_line_count(editor.buffer) - 1 {
            new_pos := buffer_line_col_to_pos(editor.buffer, line + 1, cursor.preferred_column)
            cursor.pos = new_pos
        }
        
    case .LineStart:
        line, _ := buffer_pos_to_line_col(editor.buffer, cursor.pos)
        cursor.pos = editor.buffer.line_starts[line]
        
    case .LineEnd:
        line, _ := buffer_pos_to_line_col(editor.buffer, cursor.pos)
        if line + 1 < len(editor.buffer.line_starts) {
            cursor.pos = editor.buffer.line_starts[line + 1] - 1
        } else {
            cursor.pos = len(editor.buffer.content)
        }
    }
    
    // Update preferred column for horizontal movements
    if direction == .Left || direction == .Right || direction == .LineStart || direction == .LineEnd {
        _, col := buffer_pos_to_line_col(editor.buffer, cursor.pos)
        cursor.preferred_column = col
    }
    
    // Handle selection
    if extend_selection {
        if cursor.selection_anchor == -1 {
            cursor.selection_anchor = old_pos
        }
    } else {
        cursor.selection_anchor = -1
    }
}

editor_insert_text :: proc(editor: ^Editor, text: string) {
    // Insert at all cursor positions (in reverse order to maintain positions)
    positions: [dynamic]int
    defer delete(positions)
    
    for cursor in editor.cursors {
        append(&positions, cursor.pos)
    }
    
    // Sort in descending order
    for i := 0; i < len(positions) - 1; i += 1 {
        for j := i + 1; j < len(positions); j += 1 {
            if positions[i] < positions[j] {
                positions[i], positions[j] = positions[j], positions[i]
            }
        }
    }
    
    // Insert text at each position
    for pos in positions {
        buffer_insert_text(editor.buffer, pos, text)
    }
    
    // Update cursor positions
    for &cursor, idx in editor.cursors {
        offset := 0
        for pos in positions {
            if pos <= cursor.pos {
                offset += len(text)
            }
        }
        cursor.pos += offset
        cursor.selection_anchor = -1  // Clear selection
    }
}

editor_delete_char :: proc(editor: ^Editor, forward: bool) {
    for &cursor in editor.cursors {
        if forward {
            if cursor.pos < len(editor.buffer.content) {
                buffer_delete_text(editor.buffer, cursor.pos, 1)
            }
        } else {
            if cursor.pos > 0 {
                buffer_delete_text(editor.buffer, cursor.pos - 1, 1)
                cursor.pos -= 1
            }
        }
        cursor.selection_anchor = -1  // Clear selection
    }
}

editor_get_visible_lines :: proc(editor: ^Editor) -> (start_line: int, end_line: int) {
    start_line = int(editor.scroll.y / editor.line_height)
    visible_lines := int(editor.viewport.height / editor.line_height) + 1
    end_line = min(start_line + visible_lines, buffer_get_line_count(editor.buffer))
    return start_line, end_line
}

editor_scroll_to_cursor :: proc(editor: ^Editor) {
    if len(editor.cursors) == 0 do return
    
    cursor := editor.cursors[editor.primary_cursor_idx]
    line, col := buffer_pos_to_line_col(editor.buffer, cursor.pos)
    
    cursor_y := f32(line) * editor.line_height
    cursor_x := f32(col) * editor.char_width
    
    // Vertical scrolling
    if cursor_y < editor.scroll.y {
        editor.target_scroll.y = cursor_y
    } else if cursor_y + editor.line_height > editor.scroll.y + editor.viewport.height {
        editor.target_scroll.y = cursor_y + editor.line_height - editor.viewport.height
    }
    
    // Horizontal scrolling
    if cursor_x < editor.scroll.x {
        editor.target_scroll.x = cursor_x
    } else if cursor_x + editor.char_width > editor.scroll.x + editor.viewport.width {
        editor.target_scroll.x = cursor_x + editor.char_width - editor.viewport.width
    }
}

editor_update_scroll :: proc(editor: ^Editor, dt: f32) {
    // Smooth scrolling
    SCROLL_SPEED :: 10.0
    
    diff_x := editor.target_scroll.x - editor.scroll.x
    diff_y := editor.target_scroll.y - editor.scroll.y
    
    editor.scroll.x += diff_x * SCROLL_SPEED * dt
    editor.scroll.y += diff_y * SCROLL_SPEED * dt
    
    // Snap when close enough
    if abs(diff_x) < 0.5 do editor.scroll.x = editor.target_scroll.x
    if abs(diff_y) < 0.5 do editor.scroll.y = editor.target_scroll.y
}

Movement_Direction :: enum {
    Left,
    Right,
    Up,
    Down,
    LineStart,
    LineEnd,
}