use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame,
};

use crate::core::state::AppStateManager;
use crate::core::types::BackupMode;
use crate::ui::components::{render_header, render_footer, render_security_warning};
use crate::ui::widgets::{Menu, MenuItem};

pub struct BackupModeSelectionScreen {
    menu: Menu,
}

impl BackupModeSelectionScreen {
    pub fn new() -> Self {
        let menu_items = vec![
            MenuItem::new('1', "Secure Mode".to_string(), 
                "Safe backup excluding sensitive credentials".to_string()),
            MenuItem::new('2', "Complete Mode".to_string(), 
                "Full backup including SSH keys and credentials (encrypted)".to_string()),
        ];

        Self {
            menu: Menu::new(menu_items),
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
            "Select Backup Mode",
            Some("Choose the type of backup to create"),
        );

        // Main content
        let content_chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(50), // Menu
                Constraint::Percentage(50), // Details
            ])
            .split(chunks[1]);

        // Menu
        self.menu.render(frame, content_chunks[0], "Backup Modes");

        // Details panel
        let details_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Percentage(60), // Mode details
                Constraint::Percentage(40), // Security warning (if needed)
            ])
            .split(content_chunks[1]);

        // Mode details
        let (mode_title, mode_description, mode_features) = match state.backup_mode {
            BackupMode::Secure => (
                "Secure Mode",
                "This mode creates a backup that excludes sensitive credentials and private keys. It's safe to store on cloud services or share with others.",
                vec![
                    "✓ Configuration files and settings",
                    "✓ Application data and preferences", 
                    "✓ Development tools configuration",
                    "✓ Themes and customization",
                    "✗ SSH keys and certificates",
                    "✗ Password files and credentials",
                    "✗ API keys and tokens",
                ],
            ),
            BackupMode::Complete => (
                "Complete Mode",
                "This mode creates a full backup including all files, credentials, and private keys. Requires encryption and secure storage.",
                vec![
                    "✓ All configuration files and settings",
                    "✓ Application data and preferences",
                    "✓ Development tools configuration", 
                    "✓ SSH keys and certificates",
                    "✓ GPG keys and trust database",
                    "✓ Password files and credentials",
                    "✓ API keys and authentication tokens",
                ],
            ),
        };

        let mut details_lines = vec![
            Line::from(vec![
                Span::styled(mode_title, Style::default().add_modifier(Modifier::BOLD).fg(Color::Cyan))
            ]),
            Line::from(""),
            Line::from(mode_description),
            Line::from(""),
            Line::from(vec![
                Span::styled("Included Items:", Style::default().add_modifier(Modifier::BOLD))
            ]),
        ];

        for feature in mode_features {
            let (symbol, text) = if feature.starts_with('✓') {
                ("✓", &feature[2..])
            } else {
                ("✗", &feature[2..])
            };
            
            let color = if symbol == "✓" { Color::Green } else { Color::Red };
            details_lines.push(Line::from(vec![
                Span::styled(format!("  {} ", symbol), Style::default().fg(color)),
                Span::raw(text),
            ]));
        }

        let details_paragraph = Paragraph::new(details_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Mode Details")
                    .title_alignment(Alignment::Center),
            )
            .wrap(Wrap { trim: true });

        frame.render_widget(details_paragraph, details_chunks[0]);

        // Security warning for complete mode
        if state.backup_mode == BackupMode::Complete {
            render_security_warning(
                frame,
                details_chunks[1],
                "Complete mode includes sensitive credentials like SSH keys, GPG keys, and API tokens. This backup MUST be encrypted and stored securely. Never share or store unencrypted complete backups in unsecured locations.",
            );
        } else {
            // Show security info for secure mode
            let security_info = vec![
                Line::from(vec![
                    Span::styled("Security Info", Style::default().add_modifier(Modifier::BOLD).fg(Color::Green))
                ]),
                Line::from(""),
                Line::from("Secure mode excludes sensitive files to ensure your"),
                Line::from("backup is safe to store anywhere. You can optionally"),
                Line::from("encrypt it for additional protection."),
                Line::from(""),
                Line::from("Safe for:"),
                Line::from("• Cloud storage services"),
                Line::from("• External drives"),
                Line::from("• Sharing with others"),
            ];

            let security_paragraph = Paragraph::new(security_info)
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .title("✓ Security Information")
                        .title_alignment(Alignment::Center)
                        .style(Style::default().fg(Color::Green)),
                )
                .wrap(Wrap { trim: true });

            frame.render_widget(security_paragraph, details_chunks[1]);
        }

        // Footer
        let shortcuts = [
            ("1", "Secure"),
            ("2", "Complete"),
            ("Enter", "Select"),
            ("Esc", "Back"),
        ];

        render_footer(frame, chunks[2], &shortcuts, None);
    }
}