use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame,
};

use crate::core::state::AppStateManager;
use crate::ui::components::{render_header, render_footer, render_restore_item_list, render_summary_panel};
use crate::ui::terminal::format_bytes;

pub struct RestoreItemSelectionScreen;

impl RestoreItemSelectionScreen {
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
        let archive_name = state.selected_archive
            .as_ref()
            .map(|a| a.name.as_str())
            .unwrap_or("Unknown");
        
        render_header(
            frame,
            chunks[0],
            "Select Items to Restore",
            Some(&format!("From archive: {} | Use Space to toggle, A/N to select/deselect all", archive_name)),
        );

        // Main content
        let content_chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(70), // Item list
                Constraint::Percentage(30), // Summary and details
            ])
            .split(chunks[1]);

        // Item list
        render_restore_item_list(
            frame,
            content_chunks[0],
            &state.restore_items,
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
        let (item_count, total_size, conflicts) = state.get_restore_summary();
        let summary_stats = vec![
            ("Selected Items", item_count.to_string()),
            ("Total Size", format_bytes(total_size)),
            ("Conflicts", conflicts.to_string()),
            ("Available Items", state.restore_items.len().to_string()),
        ];

        render_summary_panel(frame, right_chunks[0], "Restore Summary", &summary_stats);

        // Legend
        let legend_lines = vec![
            Line::from(vec![
                Span::styled("Legend:", Style::default().add_modifier(Modifier::BOLD))
            ]),
            Line::from(""),
            Line::from(vec![
                Span::raw("☑ "),
                Span::styled("Selected for restore", Style::default().fg(Color::Green)),
            ]),
            Line::from(vec![
                Span::raw("☐ "),
                Span::styled("Not selected", Style::default().fg(Color::Gray)),
            ]),
            Line::from(vec![
                Span::raw("⚠️ "),
                Span::styled("File conflict detected", Style::default().fg(Color::Yellow)),
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
        if let Some(item) = state.restore_items.get(state.selected_item_index) {
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
                    Span::styled("Original Path: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(item.original_path.to_string_lossy()),
                ]),
                Line::from(vec![
                    Span::styled("Restore To: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(item.restore_path.to_string_lossy()),
                ]),
                Line::from(vec![
                    Span::styled("Size: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(format_bytes(item.size)),
                ]),
            ];

            if item.conflicts {
                details_lines.push(Line::from(""));
                details_lines.push(Line::from(vec![
                    Span::styled("⚠️ Conflict Detected:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Yellow))
                ]));
                details_lines.push(Line::from("A file already exists at the restore location."));
                details_lines.push(Line::from("Restoring will overwrite the existing file."));
                details_lines.push(Line::from(""));
                details_lines.push(Line::from(vec![
                    Span::styled("Options:", Style::default().add_modifier(Modifier::BOLD))
                ]));
                details_lines.push(Line::from("• Continue: Overwrite existing file"));
                details_lines.push(Line::from("• Skip: Don't restore this item"));
                details_lines.push(Line::from("• Backup: Create backup of existing file"));
            } else {
                details_lines.push(Line::from(""));
                details_lines.push(Line::from(vec![
                    Span::styled("✓ No Conflicts:", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))
                ]));
                details_lines.push(Line::from("Safe to restore without overwriting files."));
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

        if state.is_restore_ready() {
            shortcuts.push(("Enter", "Start Restore"));
        } else {
            shortcuts.push(("Enter", "Start Restore (disabled)"));
        }

        shortcuts.push(("Esc", "Back"));

        let conflict_message = if conflicts > 0 {
            Some(format!("{} file conflicts detected - review before proceeding", conflicts))
        } else {
            None
        };
        
        let status = if !state.is_restore_ready() {
            Some("Select at least one item to restore")
        } else if let Some(ref msg) = conflict_message {
            Some(msg.as_str())
        } else {
            state.status_message.as_deref()
        };

        render_footer(frame, chunks[2], &shortcuts, status);
    }
}