package main

import "core:fmt"
import "core:slice"
import "core:strings"

Buffer :: struct {
    // Text storage
    content: [dynamic]u8,
    line_starts: [dynamic]int,  // Byte offset where each line starts

    // File info
    file_path: string,
    modified: bool,

    // History
    undo_stack: [dynamic]Edit_Operation,
    redo_stack: [dynamic]Edit_Operation,
}

Edit_Operation :: struct {
    type: Edit_Type,
    pos: int,
    text: string,
    old_text: string,  // For undo
}

Edit_Type :: enum {
    Insert,
    Delete,
    Replace,
}

buffer_new :: proc() -> ^Buffer {
    buffer := new(Buffer)
    append(&buffer.line_starts, 0)  // First line starts at 0
    return buffer
}

buffer_from_string :: proc(content: string) -> ^Buffer {
    buffer := buffer_new()
    buffer_insert_text(buffer, 0, content)
    return buffer
}

buffer_insert_text :: proc(buffer: ^Buffer, pos: int, text: string) {
    if len(text) == 0 do return

    // Insert into content
    if pos >= len(buffer.content) {
        append(&buffer.content, ..transmute([]u8)text)
    } else {
        // Make room and insert
        old_len := len(buffer.content)
        resize(&buffer.content, old_len + len(text))

        // Shift existing content
        copy(buffer.content[pos + len(text):], buffer.content[pos:old_len])

        // Insert new text
        copy(buffer.content[pos:], transmute([]u8)text)
    }

    // Update line starts
    buffer_update_line_starts(buffer, pos, len(text))
    buffer.modified = true
}

buffer_delete_text :: proc(buffer: ^Buffer, pos: int, length: int) {
    if length == 0 || pos >= len(buffer.content) do return

    actual_length := min(length, len(buffer.content) - pos)

    // Remove from content by copying remaining bytes
    if pos + actual_length < len(buffer.content) {
        copy(buffer.content[pos:], buffer.content[pos + actual_length:])
    }
    resize(&buffer.content, len(buffer.content) - actual_length)

    // Update line starts
    buffer_update_line_starts(buffer, pos, -actual_length)
    buffer.modified = true
}

buffer_update_line_starts :: proc(buffer: ^Buffer, pos: int, delta: int) {
    // After any text modification, recalculate all line starts
    // This is the safest approach to ensure correctness
    buffer_recalculate_lines(buffer)
}

buffer_recalculate_lines :: proc(buffer: ^Buffer) {
    clear(&buffer.line_starts)
    append(&buffer.line_starts, 0)

    for i, ch in buffer.content {
        if ch == '\n' {
            append(&buffer.line_starts, int(i) + 1)
        }
    }
}

buffer_get_line :: proc(buffer: ^Buffer, line_num: int) -> string {
    if line_num < 0 || line_num >= len(buffer.line_starts) do return ""

    start := buffer.line_starts[line_num]
    end: int

    if line_num + 1 < len(buffer.line_starts) {
        end = buffer.line_starts[line_num + 1] - 1  // Exclude newline
    } else {
        end = len(buffer.content)
    }

    // Ensure end doesn't exceed buffer bounds
    if end > len(buffer.content) {
        end = len(buffer.content)
    }

    if start >= end do return ""
    if start > len(buffer.content) do return ""
    
    return string(buffer.content[start:end])
}

buffer_get_line_count :: proc(buffer: ^Buffer) -> int {
    return len(buffer.line_starts)
}

buffer_pos_to_line_col :: proc(buffer: ^Buffer, pos: int) -> (line: int, col: int) {
    for i := len(buffer.line_starts) - 1; i >= 0; i -= 1 {
        if buffer.line_starts[i] <= pos {
            return i, pos - buffer.line_starts[i]
        }
    }
    return 0, 0
}

buffer_line_col_to_pos :: proc(buffer: ^Buffer, line: int, col: int) -> int {
    if line < 0 || line >= len(buffer.line_starts) do return 0

    line_start := buffer.line_starts[line]
    line_length: int

    if line + 1 < len(buffer.line_starts) {
        line_length = buffer.line_starts[line + 1] - line_start - 1
    } else {
        line_length = len(buffer.content) - line_start
    }

    return line_start + min(col, line_length)
}
