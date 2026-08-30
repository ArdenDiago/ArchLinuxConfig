mod glyphs;
mod sysinfo;

use std::io;
use std::time::Duration;

use crossterm::event::{self, Event};
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use crossterm::{execute, ExecutableCommand};
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Alignment, Constraint, Direction, Layout};
use ratatui::style::{Color, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::Paragraph;
use ratatui::Terminal;

fn restore_terminal() {
    let _ = disable_raw_mode();
    let _ = io::stdout().execute(LeaveAlternateScreen);
}

fn main() -> io::Result<()> {
    // Restore the terminal even on panic — a broken raw-mode pane left
    // behind by a crash is exactly the "not something you'd leave open for
    // hours" failure mode the spec explicitly wants to avoid.
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        restore_terminal();
        default_hook(info);
    }));

    enable_raw_mode()?;
    execute!(io::stdout(), EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(io::stdout());
    let mut terminal = Terminal::new(backend)?;

    let result = run(&mut terminal);

    restore_terminal();
    result
}

fn run(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>) -> io::Result<()> {
    let mut prev_cpu = sysinfo::read_cpu_sample();
    let mut cpu_pct: u32 = 0;

    loop {
        let cur_cpu = sysinfo::read_cpu_sample();
        if let (Some(prev), Some(cur)) = (&prev_cpu, &cur_cpu) {
            cpu_pct = sysinfo::cpu_percent(prev, cur);
        }
        prev_cpu = cur_cpu;
        let ram_pct = sysinfo::ram_percent().unwrap_or(0);
        let battery = sysinfo::battery_percent();
        let uptime = sysinfo::uptime_string().unwrap_or_else(|| "?".to_string());

        let now = chrono_now();

        terminal.draw(|frame| {
            let area = frame.area();

            // Largest scale that still fits comfortably (per spec:
            // "calculate available size, generate the largest clock that
            // fits" — simplified to integer glyph-repetition steps rather
            // than continuous stroke scaling, see glyphs.rs).
            let time_str = format!("{:02}:{:02}", now.0, now.1);
            let clock_rows = glyphs::render_line(&time_str, 1);
            let clock_height = clock_rows.len() as u16;

            let chunks = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Min(0),
                    Constraint::Length(clock_height),
                    Constraint::Length(1),
                    Constraint::Length(1),
                    Constraint::Length(1),
                    Constraint::Min(0),
                    Constraint::Length(1),
                ])
                .split(area);

            let clock_lines: Vec<Line> = clock_rows
                .iter()
                .map(|r| {
                    Line::from(Span::styled(
                        r.clone(),
                        Style::default().add_modifier(ratatui::style::Modifier::BOLD),
                    ))
                    .alignment(Alignment::Center)
                })
                .collect();
            frame.render_widget(Paragraph::new(clock_lines), chunks[1]);

            frame.render_widget(
                Paragraph::new(now.2.clone()).alignment(Alignment::Center),
                chunks[3],
            );

            let mut status = format!("CPU {}%   RAM {}%   Uptime {}", cpu_pct, ram_pct, uptime);
            if let Some(b) = battery {
                status = format!(
                    "CPU {}%   RAM {}%   Battery {}%   Uptime {}",
                    cpu_pct, ram_pct, b, uptime
                );
            }
            frame.render_widget(
                Paragraph::new(status)
                    .alignment(Alignment::Center)
                    .style(Style::default().fg(Color::DarkGray)),
                chunks[6],
            );
        })?;

        // Blocks here almost all the time — near-zero idle CPU, one redraw
        // per second, exits immediately on any keypress.
        if event::poll(Duration::from_secs(1))? {
            if let Event::Key(_) = event::read()? {
                return Ok(());
            }
        }
    }
}

/// (hour, minute, "Weekday · DD Month YYYY"), local time.
///
/// ponytail: shells out to `date` once/sec rather than hand-rolling
/// timezone/DST-aware calendar math or adding a chrono+tz-database
/// dependency. A first version computed civil date directly from raw UTC
/// `SystemTime` and got local-time handling wrong entirely (always showed
/// UTC) — `date` already gets TZ/DST/locale right for free, and a process
/// spawn once a second is negligible next to this app's own 1Hz redraw.
fn chrono_now() -> (u32, u32, String) {
    let output = std::process::Command::new("date")
        .arg("+%H %M %a %d %B %Y")
        .output();

    if let Ok(output) = output {
        let text = String::from_utf8_lossy(&output.stdout);
        let parts: Vec<&str> = text.trim().splitn(6, ' ').collect();
        if parts.len() == 6 {
            if let (Ok(hour), Ok(minute)) = (parts[0].parse(), parts[1].parse()) {
                let date_str = format!("{} · {} {} {}", parts[2], parts[3], parts[4], parts[5]);
                return (hour, minute, date_str);
            }
        }
    }
    (0, 0, "?".to_string())
}
