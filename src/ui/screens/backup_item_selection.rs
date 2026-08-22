use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
};

use crate::core::state::AppStateManager;
use crate::core::types::SecurityLevel;
use crate::ui::components::{render_header, render_footer, render_backup_item_list, render_summary_panel};
use crate::ui::terminal::format_bytes;

pub struct BackupItemSelectionScreen;

impl BackupItemSelectionScreen {
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
        let mode_name = match state.backup_mode {
            crate::core::types::BackupMode::Secure => "Secure Mode",
            crate::core::types::BackupMode::Complete => "Complete Mode",
        };
        
        render_header(
            frame,
            chunks[0],
            "Select Items to Backup",
            Some(&format!("Mode: {} | Use Space to toggle, A/N to select/deselect all", mode_name)),
        );

        // Main content
        let content_chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(70), // Item list
                Constraint::Percentage(30), // Summary and legend
            ])
            .split(chunks[1]);

        // Item list
        let available_height = content_chunks[0].height.saturating_sub(2) as usize;
        render_backup_item_list(
            frame,
            content_chunks[0],
            &state.backup_items,
            state.selected_item_index,
            state.scroll_offset,
        );

        // Right panel
        let right_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(8),  // Summary
                Constraint::Length(8),  // Legend
                Constraint::Min(0),     // Item details
            ])
            .split(content_chunks[1]);

        // Summary
        let (item_count, total_size, high_security_count) = state.get_backup_summary();
        let summary_stats = vec![
            ("Selected Items", item_count.to_string()),
            ("Total Size", format_bytes(total_size)),
            ("High Security", high_security_count.to_string()),
            ("Missing Items", state.backup_items.iter().filter(|item| !item.exists).count().to_string()),
        ];

        render_summary_panel(frame, right_chunks[0], "Backup Summary", &summary_stats);

        // Legend
        let legend_lines = vec![
            Line::from(vec![
                Span::styled("Legend:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from(""),
            Line::from(vec![
                Span::raw("☑ "),
                Span::styled("Selected", Style::default().fg(Color::Green)),
            ]),
            Line::from(vec![
                Span::raw("☐ "),
                Span::styled("Not selected", Style::default().fg(Color::Gray)),
            ]),
            Line::from(vec![
                Span::raw("🔒 "),
                Span::styled("High security", Style::default().fg(Color::Red)),
            ]),
            Line::from(vec![
                Span::raw("⚠️ "),
                Span::styled("Medium security", Style::default().fg(Color::Yellow)),
            ]),
            Line::from(vec![
                Span::raw("❌ "),
                Span::styled("Missing/Not found", Style::default().fg(Color::Red)),
            ]),
        ];

        let legend_paragraph = Paragraph::new(legend_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Legend")
                    .title_alignment(Alignment::Center),
            )
            .wrap(Wrap { trim: true });

        frame.render_widget(legend_paragraph, right_chunks[1]);

        // Item details
        if let Some(item) = state.backup_items.get(state.selected_item_index) {
            let mut details_lines = vec![
                Line::from(vec![
                    Span::styled("Selected Item:", Style::default().add_modifier(Modifier::BOLD))
                ]),
                Line::from(""),
                Line::from(vec![
                    Span::styled("Name: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(&item.name),
                ]),
                Line::from(vec![
                    Span::styled("Path: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(item.path.to_string_lossy()),
                ]),
                Line::from(vec![
                    Span::styled("Category: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(&item.category),
                ]),
                Line::from(vec![
                    Span::styled("Size: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(item.size.map(format_bytes).unwrap_or_else(|| "Unknown".to_string())),
                ]),
                Line::from(vec![
                    Span::styled("Security: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::styled(
                        match item.security_level {
                            SecurityLevel::High => "High",
                            SecurityLevel::Medium => "Medium", 
                            SecurityLevel::Low => "Low",
                        },
                        Style::default().fg(item.security_level.color()),
                    ),
                ]),
                Line::from(vec![
                    Span::styled("Status: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::styled(
                        if item.exists { "Found" } else { "Missing" },
                        Style::default().fg(if item.exists { Color::Green } else { Color::Red }),
                    ),
                ]),
            ];

            if !item.description.is_empty() {
                details_lines.push(Line::from(""));
                details_lines.push(Line::from(vec![
                    Span::styled("Description:", Style::default().add_modifier(Modifier::BOLD))
                ]));
                details_lines.push(Line::from(item.description.clone()));
            }

            if let Some(warning) = &item.warning {
                details_lines.push(Line::from(""));
                details_lines.push(Line::from(vec![
                    Span::styled("⚠️ Warning:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Yellow))
                ]));
                details_lines.push(Line::from(vec![
                    Span::styled(warning, Style::default().fg(Color::Yellow))
                ]));
            }

            let details_paragraph = Paragraph::new(details_lines)
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .title("Item Details")
                        .title_alignment(Alignment::Center),
                )
                .wrap(Wrap { trim: true });

            frame.render_widget(details_paragraph, right_chunks[2]);
        }

        // Footer
        let mut shortcuts = vec![
            ("↑↓", "Navigate"),
            ("Space", "Toggle"),
            ("A", "Select All"),
            ("N", "Select None"),
        ];

        if state.is_backup_ready() {
            shortcuts.push(("Enter", "Continue"));
        } else {
            shortcuts.push(("Enter", "Continue (disabled)"));
        }

        shortcuts.push(("Esc", "Back"));

        let status = if !state.is_backup_ready() {
            Some("Select at least one item to continue")
        } else {
            state.status_message.as_deref()
        };

        render_footer(frame, chunks[2], &shortcuts, status);
    }
}