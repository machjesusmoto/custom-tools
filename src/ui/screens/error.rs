use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame,
};

use crate::core::state::AppStateManager;
use crate::ui::components::{render_header, render_footer};
use crate::ui::terminal::centered_rect;

pub struct ErrorScreen;

impl ErrorScreen {
    pub fn new() -> Self {
        Self
    }

    pub fn render(&mut self, frame: &mut ratatui::Frame, state: &AppStateManager) {
        let size = frame.area();
        
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(4),  // Header
                Constraint::Min(0),     // Content
                Constraint::Length(3),  // Footer
            ])
            .split(size);

        // Header
        render_header(
            frame,
            chunks[0],
            "Error",
            Some("An error has occurred"),
        );

        // Error content (centered)
        let error_area = centered_rect(80, 60, chunks[1]);
        
        let error_message = if let crate::core::state::AppState::Error(ref error) = state.current_state {
            error.clone()
        } else {
            state.error_message.clone().unwrap_or_else(|| "Unknown error occurred".to_string())
        };

        let error_lines = vec![
            Line::from(""),
            Line::from(vec![
                Span::styled("❌ Error Details:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Red))
            ]),
            Line::from(""),
            Line::from(error_message),
            Line::from(""),
            Line::from(""),
            Line::from(vec![
                Span::styled("What you can do:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Press Enter or Esc to return to the previous screen"),
            Line::from("• Check the error message for specific details"),
            Line::from("• Try the operation again with different settings"),
            Line::from("• Use Ctrl+H to view the help guide"),
            Line::from("• Enable debug mode for more detailed logging"),
            Line::from(""),
            Line::from(vec![
                Span::styled("Common Solutions:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Ensure you have sufficient disk space"),
            Line::from("• Check file and directory permissions"),
            Line::from("• Verify the backup configuration is correct"),
            Line::from("• Make sure required tools are installed"),
            Line::from("• Try with a smaller selection of files"),
        ];

        let error_paragraph = Paragraph::new(error_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Error Information")
                    .title_alignment(Alignment::Center)
                    .style(Style::default().fg(Color::Red)),
            )
            .alignment(Alignment::Left)
            .wrap(Wrap { trim: true });

        frame.render_widget(error_paragraph, error_area);

        // Footer
        let shortcuts = [
            ("Enter", "Return"),
            ("Esc", "Return"),
            ("Ctrl+H", "Help"),
        ];

        render_footer(frame, chunks[2], &shortcuts, Some("Review the error and try again"));
    }
}