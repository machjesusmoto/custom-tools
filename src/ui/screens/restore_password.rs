use crossterm::event::KeyEvent;
use ratatui::{
    layout::{Constraint, Direction, Layout},
    Frame,
};

use crate::core::security::SecurePassword;
use crate::core::state::AppStateManager;
use crate::ui::components::{render_header, render_footer};
use crate::ui::widgets::PasswordInput;
use crate::ui::terminal::centered_rect;

pub struct RestorePasswordScreen {
    password_input: PasswordInput,
}

impl RestorePasswordScreen {
    pub fn new() -> Self {
        Self {
            password_input: PasswordInput::new(false, false), // No strength check, no confirm
        }
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
        let archive_name = state.selected_archive
            .as_ref()
            .map(|a| a.name.as_str())
            .unwrap_or("Unknown");

        render_header(
            frame,
            chunks[0],
            "Archive Password Required",
            Some(&format!("Enter password to unlock archive: {}", archive_name)),
        );

        // Password input (centered)
        let password_area = centered_rect(50, 40, chunks[1]);
        self.password_input.render(frame, password_area);

        // Footer
        let shortcuts = [
            ("Enter", "Unlock Archive"),
            ("Esc", "Back"),
        ];

        render_footer(frame, chunks[2], &shortcuts, None);
    }

    pub fn handle_key(&mut self, key: KeyEvent) -> Option<SecurePassword> {
        self.password_input.handle_key(key)
    }
}