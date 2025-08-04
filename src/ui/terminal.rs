use anyhow::{Context, Result};
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::{Backend, CrosstermBackend},
    Terminal as RatatuiTerminal,
    Frame,
};
use std::{
    io::{self, Stdout},
    time::Duration,
};

pub struct Terminal {
    terminal: RatatuiTerminal<CrosstermBackend<Stdout>>,
}

impl Terminal {
    pub fn new() -> Result<Self> {
        // Setup terminal
        enable_raw_mode().context("Failed to enable raw mode")?;
        let mut stdout = io::stdout();
        execute!(stdout, EnterAlternateScreen, EnableMouseCapture)
            .context("Failed to setup terminal")?;
        
        let backend = CrosstermBackend::new(stdout);
        let terminal = RatatuiTerminal::new(backend)
            .context("Failed to create terminal")?;
        
        Ok(Self { terminal })
    }

    pub fn draw<F>(&mut self, f: F) -> Result<()>
    where
        F: FnOnce(&mut ratatui::Frame),
    {
        self.terminal
            .draw(f)
            .context("Failed to draw to terminal")?;
        Ok(())
    }

    pub async fn next_event(&mut self) -> Result<Option<Event>> {
        // Check for events with timeout to allow for periodic updates
        if event::poll(Duration::from_millis(100))? {
            Ok(Some(event::read().context("Failed to read event")?))
        } else {
            Ok(None) // No event available
        }
    }

    pub fn cleanup(&mut self) -> Result<()> {
        // Restore terminal
        disable_raw_mode().context("Failed to disable raw mode")?;
        execute!(
            self.terminal.backend_mut(),
            LeaveAlternateScreen,
            DisableMouseCapture
        )
        .context("Failed to cleanup terminal")?;
        self.terminal.show_cursor().context("Failed to show cursor")?;
        
        Ok(())
    }

    pub fn size(&self) -> Result<ratatui::layout::Rect> {
        let size = self.terminal.size().context("Failed to get terminal size")?;
        Ok(ratatui::layout::Rect::new(0, 0, size.width, size.height))
    }
}

impl Drop for Terminal {
    fn drop(&mut self) {
        // Ensure cleanup happens even if not called explicitly
        let _ = self.cleanup();
    }
}

/// Helper function to center a rectangle within another rectangle
pub fn centered_rect(percent_x: u16, percent_y: u16, r: ratatui::layout::Rect) -> ratatui::layout::Rect {
    use ratatui::layout::{Constraint, Direction, Layout, Margin};
    
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(r);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}

/// Helper function to format bytes in a human-readable format
pub fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    let mut size = bytes as f64;
    let mut unit_index = 0;

    while size >= 1024.0 && unit_index < UNITS.len() - 1 {
        size /= 1024.0;
        unit_index += 1;
    }

    if unit_index == 0 {
        format!("{} {}", bytes, UNITS[unit_index])
    } else {
        format!("{:.1} {}", size, UNITS[unit_index])
    }
}

/// Helper function to format duration in a human-readable format
pub fn format_duration(duration: std::time::Duration) -> String {
    let total_seconds = duration.as_secs();
    let hours = total_seconds / 3600;
    let minutes = (total_seconds % 3600) / 60;
    let seconds = total_seconds % 60;

    if hours > 0 {
        format!("{}h {}m {}s", hours, minutes, seconds)
    } else if minutes > 0 {
        format!("{}m {}s", minutes, seconds)
    } else {
        format!("{}s", seconds)
    }
}

/// Helper function to truncate text to fit within a specific width
pub fn truncate_text(text: &str, max_width: usize) -> String {
    if text.len() <= max_width {
        text.to_string()
    } else if max_width <= 3 {
        "...".to_string()
    } else {
        format!("{}...", &text[..max_width - 3])
    }
}

/// Helper function to create a progress bar string
pub fn create_progress_bar(percentage: f64, width: usize) -> String {
    let filled_width = ((percentage / 100.0) * width as f64) as usize;
    let empty_width = width.saturating_sub(filled_width);
    
    format!(
        "{}{}",
        "█".repeat(filled_width),
        "░".repeat(empty_width)
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_format_bytes() {
        assert_eq!(format_bytes(512), "512 B");
        assert_eq!(format_bytes(1024), "1.0 KB");
        assert_eq!(format_bytes(1536), "1.5 KB");
        assert_eq!(format_bytes(1048576), "1.0 MB");
        assert_eq!(format_bytes(1073741824), "1.0 GB");
    }

    #[test]
    fn test_format_duration() {
        assert_eq!(format_duration(Duration::from_secs(30)), "30s");
        assert_eq!(format_duration(Duration::from_secs(90)), "1m 30s");
        assert_eq!(format_duration(Duration::from_secs(3661)), "1h 1m 1s");
    }

    #[test]
    fn test_truncate_text() {
        assert_eq!(truncate_text("hello", 10), "hello");
        assert_eq!(truncate_text("hello world", 8), "hello...");
        assert_eq!(truncate_text("hi", 2), "hi");
        assert_eq!(truncate_text("hello", 3), "...");
    }

    #[test]
    fn test_create_progress_bar() {
        assert_eq!(create_progress_bar(0.0, 10), "░░░░░░░░░░");
        assert_eq!(create_progress_bar(50.0, 10), "█████░░░░░");
        assert_eq!(create_progress_bar(100.0, 10), "██████████");
    }
}