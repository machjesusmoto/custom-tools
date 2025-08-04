use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame,
};

use crate::core::state::AppStateManager;
use crate::ui::components::{render_header, render_footer};

pub struct HelpScreen;

impl HelpScreen {
    pub fn new() -> Self {
        Self
    }

    pub fn render(&mut self, frame: &mut ratatui::Frame, _state: &AppStateManager) {
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
            "Help & Usage Guide",
            Some("Backup & Restore System Documentation"),
        );

        // Content
        let content_chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(50), // Left column
                Constraint::Percentage(50), // Right column
            ])
            .split(chunks[1]);

        // Left column - General help
        let left_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Percentage(60), // Navigation & Controls
                Constraint::Percentage(40), // Backup Modes
            ])
            .split(content_chunks[0]);

        // Navigation and Controls
        let navigation_lines = vec![
            Line::from(vec![
                Span::styled("Navigation & Controls:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Cyan))
            ]),
            Line::from(""),
            Line::from(vec![
                Span::styled("Global Controls:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• ↑↓ / k,j - Navigate up/down"),
            Line::from("• Enter - Select/Confirm"),
            Line::from("• Esc - Go back/Cancel"),
            Line::from("• Ctrl+C - Quit application"),
            Line::from("• Ctrl+H - Show this help"),
            Line::from("• Q - Quit (context-dependent)"),
            Line::from(""),
            Line::from(vec![
                Span::styled("List Controls:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Space - Toggle item selection"),
            Line::from("• A - Select all items"),
            Line::from("• N - Deselect all items"),
            Line::from("• Page Up/Down - Fast scroll"),
            Line::from(""),
            Line::from(vec![
                Span::styled("Password Input:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Type - Enter password (hidden)"),
            Line::from("• Tab - Switch between fields"),
            Line::from("• Backspace - Delete character"),
            Line::from("• ←→ - Move cursor"),
        ];

        let navigation_paragraph = Paragraph::new(navigation_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Navigation")
                    .title_alignment(Alignment::Center),
            )
            .wrap(Wrap { trim: true });

        frame.render_widget(navigation_paragraph, left_chunks[0]);

        // Backup Modes
        let modes_lines = vec![
            Line::from(vec![
                Span::styled("Backup Modes:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Cyan))
            ]),
            Line::from(""),
            Line::from(vec![
                Span::styled("🔰 Secure Mode:", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Excludes sensitive credentials"),
            Line::from("• Safe for cloud storage/sharing"),
            Line::from("• No password required (optional)"),
            Line::from("• Includes: configs, themes, app data"),
            Line::from("• Excludes: SSH keys, GPG keys, tokens"),
            Line::from(""),
            Line::from(vec![
                Span::styled("🔑 Complete Mode:", Style::default().fg(Color::Red).add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Includes ALL files and credentials"),
            Line::from("• Requires strong password"),
            Line::from("• Must be stored securely"),
            Line::from("• Includes: everything from secure mode"),
            Line::from("• Plus: SSH keys, GPG keys, passwords"),
        ];

        let modes_paragraph = Paragraph::new(modes_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Backup Modes")
                    .title_alignment(Alignment::Center),
            )
            .wrap(Wrap { trim: true });

        frame.render_widget(modes_paragraph, left_chunks[1]);

        // Right column
        let right_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Percentage(50), // Security & Best Practices
                Constraint::Percentage(50), // Troubleshooting
            ])
            .split(content_chunks[1]);

        // Security & Best Practices
        let security_lines = vec![
            Line::from(vec![
                Span::styled("Security & Best Practices:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Cyan))
            ]),
            Line::from(""),
            Line::from(vec![
                Span::styled("Password Security:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Use strong, unique passwords"),
            Line::from("• Mix uppercase, lowercase, numbers, symbols"),
            Line::from("• Minimum 12 characters recommended"),
            Line::from("• Store passwords in a password manager"),
            Line::from("• Never share encrypted backup passwords"),
            Line::from(""),
            Line::from(vec![
                Span::styled("Backup Storage:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Secure mode: Safe for cloud storage"),
            Line::from("• Complete mode: Local/encrypted storage only"),
            Line::from("• Keep multiple backup copies"),
            Line::from("• Test restore procedures regularly"),
            Line::from("• Store backups in different locations"),
            Line::from(""),
            Line::from(vec![
                Span::styled("File Permissions:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Restored files keep original permissions"),
            Line::from("• SSH keys: 600 (owner read/write only)"),
            Line::from("• Config files: 644 (owner rw, others r)"),
            Line::from("• Directories: 755 (standard permissions)"),
        ];

        let security_paragraph = Paragraph::new(security_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Security")
                    .title_alignment(Alignment::Center),
            )
            .wrap(Wrap { trim: true });

        frame.render_widget(security_paragraph, right_chunks[0]);

        // Troubleshooting
        let troubleshooting_lines = vec![
            Line::from(vec![
                Span::styled("Troubleshooting:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Cyan))
            ]),
            Line::from(""),
            Line::from(vec![
                Span::styled("Common Issues:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Missing files: Check paths exist"),
            Line::from("• Permission denied: Run with sudo if needed"),
            Line::from("• Disk space: Ensure enough free space"),
            Line::from("• Archive corrupt: Verify backup integrity"),
            Line::from("• Wrong password: Check caps lock, try again"),
            Line::from(""),
            Line::from(vec![
                Span::styled("File Conflicts:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• ⚠️ Yellow warning: File will be overwritten"),
            Line::from("• Review conflicts before restoring"),
            Line::from("• Backup existing files if unsure"),
            Line::from("• Use selective restore for safety"),
            Line::from(""),
            Line::from(vec![
                Span::styled("Getting Help:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from("• Check application logs for details"),
            Line::from("• Verify tool dependencies are installed"),
            Line::from("• Try with debug mode enabled (-d flag)"),
            Line::from("• Test with smaller backup sets first"),
        ];

        let troubleshooting_paragraph = Paragraph::new(troubleshooting_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Troubleshooting")
                    .title_alignment(Alignment::Center),
            )
            .wrap(Wrap { trim: true });

        frame.render_widget(troubleshooting_paragraph, right_chunks[1]);

        // Footer
        let shortcuts = [
            ("Esc", "Back"),
            ("Q", "Back"),
        ];

        render_footer(frame, chunks[2], &shortcuts, Some("Press Esc or Q to return"));
    }
}