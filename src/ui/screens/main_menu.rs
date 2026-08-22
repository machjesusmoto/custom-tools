use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
};

use crate::core::state::AppStateManager;
use crate::ui::components::{render_header, render_footer};
use crate::ui::widgets::{Menu, MenuItem};

pub struct MainMenuScreen {
    menu: Menu,
}

impl MainMenuScreen {
    pub fn new() -> Self {
        let menu_items = vec![
            MenuItem::new('1', "Backup".to_string(), "Create a backup of your files".to_string()),
            MenuItem::new('2', "Restore".to_string(), "Restore files from a backup".to_string()),
            MenuItem::new('q', "Quit".to_string(), "Exit the application".to_string()),
        ];

        Self {
            menu: Menu::new(menu_items),
        }
    }

    pub fn handle_key(&mut self, key: crossterm::event::KeyEvent) -> Option<char> {
        self.menu.handle_key(key)
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
            "Backup & Restore System",
            Some("Select an option to continue"),
        );

        // Main content
        let content_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(15), // Menu
                Constraint::Min(0),     // Welcome text
            ])
            .split(chunks[1]);

        // Menu
        self.menu.render(frame, content_chunks[0], "Main Menu");

        // Welcome text
        let welcome_text = vec![
            Line::from(""),
            Line::from(vec![
                Span::styled("Welcome to the Backup & Restore System", 
                    Style::default().add_modifier(Modifier::BOLD).fg(Color::Cyan))
            ]),
            Line::from(""),
            Line::from("This tool helps you safely backup and restore your important files."),
            Line::from("Choose from secure mode (excludes sensitive data) or complete mode"),
            Line::from("(includes all files with encryption support)."),
            Line::from(""),
            Line::from(vec![
                Span::styled("Security Features:", Style::default().add_modifier(Modifier::BOLD)),
            ]),
            Line::from("• Password-protected backups with strong encryption"),
            Line::from("• Secure memory handling for passwords"),
            Line::from("• File integrity verification"),
            Line::from("• Selective restore with conflict detection"),
        ];

        let welcome_paragraph = Paragraph::new(welcome_text)
            .alignment(Alignment::Center)
            .wrap(Wrap { trim: true })
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Information")
                    .title_alignment(Alignment::Center),
            );

        frame.render_widget(welcome_paragraph, content_chunks[1]);

        // Footer
        let shortcuts = [
            ("1", "Backup"),
            ("2", "Restore"),
            ("Ctrl+H", "Help"),
            ("Q", "Quit"),
        ];

        let status = state.status_message.as_deref();
        render_footer(frame, chunks[2], &shortcuts, status);
    }
}