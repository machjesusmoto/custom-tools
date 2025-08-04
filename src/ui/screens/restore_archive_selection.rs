use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph, Wrap},
};

use crate::core::state::AppStateManager;
use crate::ui::components::{render_header, render_footer};
use crate::ui::terminal::format_bytes;

pub struct RestoreArchiveSelectionScreen;

impl RestoreArchiveSelectionScreen {
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
            "Select Archive to Restore",
            Some("Choose a backup archive to restore from"),
        );

        if state.available_archives.is_empty() {
            // No archives found
            let no_archives_text = vec![
                Line::from(""),
                Line::from(vec![
                    Span::styled("No backup archives found", 
                        Style::default().add_modifier(Modifier::BOLD).fg(Color::Yellow))
                ]),
                Line::from(""),
                Line::from("Make sure backup files are in the correct location."),
                Line::from("Supported formats: .tar.gz, .tar.xz (encrypted and unencrypted)"),
                Line::from(""),
                Line::from("Create a backup first using the backup option from the main menu."),
            ];

            let no_archives_paragraph = Paragraph::new(no_archives_text)
                .alignment(Alignment::Center)
                .wrap(Wrap { trim: true })
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .title("No Archives Available")
                        .title_alignment(Alignment::Center),
                );

            frame.render_widget(no_archives_paragraph, chunks[1]);
        } else {
            // Main content
            let content_chunks = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([
                    Constraint::Percentage(60), // Archive list
                    Constraint::Percentage(40), // Archive details
                ])
                .split(chunks[1]);

            // Archive list
            let archive_items: Vec<ListItem> = state.available_archives
                .iter()
                .enumerate()
                .map(|(i, archive)| {
                    let is_selected = i == state.selected_item_index;
                    
                    let encryption_icon = if archive.encrypted { "🔒" } else { " " };
                    let mode_icon = match archive.mode {
                        crate::core::types::BackupMode::Secure => "🔰",
                        crate::core::types::BackupMode::Complete => "🔑",
                    };
                    
                    let item_text = format!(
                        "{} {} {} ({})",
                        encryption_icon,
                        mode_icon,
                        archive.name,
                        format_bytes(archive.size)
                    );
                    
                    let style = if is_selected {
                        Style::default().bg(Color::Blue).fg(Color::White)
                    } else {
                        Style::default()
                    };
                    
                    ListItem::new(item_text).style(style)
                })
                .collect();

            let archive_list = List::new(archive_items)
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .title("Available Archives")
                        .title_alignment(Alignment::Center),
                )
                .highlight_style(Style::default().add_modifier(Modifier::BOLD));

            frame.render_widget(archive_list, content_chunks[0]);

            // Archive details
            if let Some(archive) = state.available_archives.get(state.selected_item_index) {
                let created_str = archive.created.format("%Y-%m-%d %H:%M:%S UTC").to_string();
                let mode_str = match archive.mode {
                    crate::core::types::BackupMode::Secure => "Secure Mode",
                    crate::core::types::BackupMode::Complete => "Complete Mode",
                };

                let mut details_lines = vec![
                    Line::from(vec![
                        Span::styled("Archive Details:", Style::default().add_modifier(Modifier::BOLD))
                    ]),
                    Line::from(""),
                    Line::from(vec![
                        Span::styled("Name: ", Style::default().add_modifier(Modifier::BOLD)),
                        Span::raw(&archive.name),
                    ]),
                    Line::from(vec![
                        Span::styled("Created: ", Style::default().add_modifier(Modifier::BOLD)),
                        Span::raw(&created_str),
                    ]),
                    Line::from(vec![
                        Span::styled("Size: ", Style::default().add_modifier(Modifier::BOLD)),
                        Span::raw(format_bytes(archive.size)),
                    ]),
                    Line::from(vec![
                        Span::styled("Mode: ", Style::default().add_modifier(Modifier::BOLD)),
                        Span::raw(mode_str),
                    ]),
                    Line::from(vec![
                        Span::styled("Encrypted: ", Style::default().add_modifier(Modifier::BOLD)),
                        Span::styled(
                            if archive.encrypted { "Yes" } else { "No" },
                            Style::default().fg(if archive.encrypted { Color::Green } else { Color::Gray }),
                        ),
                    ]),
                    Line::from(vec![
                        Span::styled("Items: ", Style::default().add_modifier(Modifier::BOLD)),
                        Span::raw(archive.items.len().to_string()),
                    ]),
                ];

                if !archive.description.is_empty() {
                    details_lines.push(Line::from(""));
                    details_lines.push(Line::from(vec![
                        Span::styled("Description:", Style::default().add_modifier(Modifier::BOLD))
                    ]));
                    details_lines.push(Line::from(archive.description.clone()));
                }

                // Add security information
                details_lines.push(Line::from(""));
                match archive.mode {
                    crate::core::types::BackupMode::Secure => {
                        details_lines.push(Line::from(vec![
                            Span::styled("🔰 Secure Mode:", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))
                        ]));
                        details_lines.push(Line::from("Excludes sensitive credentials"));
                        details_lines.push(Line::from("Safe to restore on shared systems"));
                    }
                    crate::core::types::BackupMode::Complete => {
                        details_lines.push(Line::from(vec![
                            Span::styled("🔑 Complete Mode:", Style::default().fg(Color::Red).add_modifier(Modifier::BOLD))
                        ]));
                        details_lines.push(Line::from("Contains sensitive credentials"));
                        details_lines.push(Line::from("Use caution when restoring"));
                    }
                }

                if archive.encrypted {
                    details_lines.push(Line::from(""));
                    details_lines.push(Line::from(vec![
                        Span::styled("🔒 Encrypted:", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD))
                    ]));
                    details_lines.push(Line::from("Password required to access"));
                }

                let details_paragraph = Paragraph::new(details_lines)
                    .block(
                        Block::default()
                            .borders(Borders::ALL)
                            .title("Archive Information")
                            .title_alignment(Alignment::Center),
                    )
                    .wrap(Wrap { trim: true });

                frame.render_widget(details_paragraph, content_chunks[1]);
            }
        }

        // Footer
        let mut shortcuts = vec![
            ("↑↓", "Navigate"),
        ];

        if !state.available_archives.is_empty() {
            shortcuts.push(("Enter", "Select"));
        }

        shortcuts.extend_from_slice(&[
            ("Esc", "Back"),
            ("Ctrl+H", "Help"),
        ]);

        let status = if state.available_archives.is_empty() {
            Some("No archives available for restore")
        } else {
            state.status_message.as_deref()
        };

        render_footer(frame, chunks[2], &shortcuts, status);
    }
}