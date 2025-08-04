use crossterm::event::KeyEvent;
use ratatui::layout::{Constraint, Direction, Layout};

use crate::core::security::SecurePassword;
use crate::core::state::AppStateManager;
use crate::ui::components::{render_header, render_footer};
use crate::ui::widgets::PasswordInput;
use crate::ui::terminal::centered_rect;

pub struct BackupPasswordScreen {
    password_input: PasswordInput,
}

impl BackupPasswordScreen {
    pub fn new() -> Self {
        Self {
            password_input: PasswordInput::new(true, true), // Show strength, confirm mode
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
        render_header(
            frame,
            chunks[0],
            "Backup Encryption Password",
            Some("Complete mode requires encryption - enter a strong password"),
        );

        // Password input (centered)
        let password_area = centered_rect(60, 60, chunks[1]);
        self.password_input.render(frame, password_area);

        // Footer
        let shortcuts = [
            ("Tab", "Switch fields"),
            ("Enter", "Continue"),
            ("Esc", "Back"),
        ];

        render_footer(frame, chunks[2], &shortcuts, None);
    }

    pub fn handle_key(&mut self, key: KeyEvent) -> Option<SecurePassword> {
        self.password_input.handle_key(key)
    }
}