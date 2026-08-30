//! Custom digit typography — no FIGlet, no block-character (█) art, per the
//! spec. Each glyph is a hand-defined 3-row template built from box-drawing
//! line characters.
//!
//! ponytail: fixed native size, no scaling. Naive character-repetition
//! scaling was tried first and rejected — box-drawing corner/line glyphs
//! (╭ ─ ╮) aren't tileable by repeating each cell, it just produces
//! garbled rows of disconnected corner symbols instead of a bigger digit.
//! Real scaling needs either multiple hand-designed glyph sets per size
//! tier or a proper stroke-based vector renderer (the spec's original
//! ask) — both are real work, deferred until this fixed-size version is
//! confirmed to read well. `scale` is kept as a parameter (always 1) so
//! that upgrade path doesn't require changing every call site.

pub const DIGIT_HEIGHT: usize = 3;

pub fn digit_glyph(c: char) -> [&'static str; DIGIT_HEIGHT] {
    match c {
        '0' => ["╭─╮", "│ │", "╰─╯"],
        '1' => [" ╷ ", " │ ", " ╵ "],
        '2' => ["╶─╮", "╭─╯", "╰─╴"],
        '3' => ["╶─╮", " ─┤", "╶─╯"],
        '4' => ["╷ ╷", "╰─┤", "  ╵"],
        '5' => ["╭─╴", "╰─╮", "╶─╯"],
        '6' => ["╭─╴", "├─╮", "╰─╯"],
        '7' => ["╶─╮", "  │", "  ╵"],
        '8' => ["╭─╮", "├─┤", "╰─╯"],
        '9' => ["╭─╮", "╰─┤", "╶─╯"],
        ':' => ["   ", " ╻ ", " ╹ "],
        _ => ["   ", "   ", "   "],
    }
}

/// Renders `text` (digits and `:` only) at native size, one glyph-column
/// gap between characters, returning one String per output row.
pub fn render_line(text: &str, _scale: usize) -> Vec<String> {
    let glyphs: Vec<[&str; DIGIT_HEIGHT]> = text.chars().map(digit_glyph).collect();
    let mut rows = vec![String::new(); DIGIT_HEIGHT];

    for glyph in &glyphs {
        for (row_idx, row) in glyph.iter().enumerate() {
            rows[row_idx].push_str(row);
            rows[row_idx].push(' ');
        }
    }
    rows
}

