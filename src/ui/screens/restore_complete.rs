use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame,
};

use crate::core::state::AppStateManager;
use crate::core::types::ProgressStatus;
use crate::ui::components::{render_header, render_footer};
use crate::ui::terminal::format_bytes;

pub struct RestoreCompleteScreen;

impl RestoreCompleteScreen {
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
        let header_title = if let Some(progress) = &state.restore_progress {
            match progress.status {
                ProgressStatus::Completed => "Restore Completed Successfully",
                ProgressStatus::Failed(_) => "Restore Failed",
                _ => "Restore Status",
            }
        } else {
            "Restore Complete"
        };

        render_header(
            frame,
            chunks[0],
            header_title,
            Some("Your restore operation has finished"),
        );

        // Content
        let content_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(12), // Summary
                Constraint::Min(0),     // Details/Actions
            ])
            .split(chunks[1]);

        // Summary
        let mut summary_lines = vec![];
        
        if let Some(progress) = &state.restore_progress {
            match &progress.status {
                ProgressStatus::Completed => {
                    summary_lines.push(Line::from(vec![
                        Span::styled("✅ Restore completed successfully!", 
                            Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))
                    ]));
                    summary_lines.push(Line::from(""));
                    
                    let duration = chrono::Utc::now().signed_duration_since(progress.start_time);
                    let duration_str = if duration.num_hours() > 0 {
                        format!("{}h {}m {}s", duration.num_hours(), duration.num_minutes() % 60, duration.num_seconds() % 60)
                    } else if duration.num_minutes() > 0 {
                        format!("{}m {}s", duration.num_minutes(), duration.num_seconds() % 60)
                    } else {
                        format!("{}s", duration.num_seconds())
                    };

                    summary_lines.push(Line::from(vec![
                        Span::styled("Summary:", Style::default().add_modifier(Modifier::BOLD))
                    ]));
                    summary_lines.push(Line::from(format!("• Items restored: {}", progress.items_completed)));
                    summary_lines.push(Line::from(format!("• Data restored: {}", format_bytes(progress.bytes_processed))));
                    summary_lines.push(Line::from(format!("• Time taken: {}", duration_str)));
                    
                    if progress.conflicts_resolved > 0 {
                        summary_lines.push(Line::from(format!("• Conflicts resolved: {}", progress.conflicts_resolved)));
                    }
                    
                    if let Some(archive) = &state.selected_archive {
                        summary_lines.push(Line::from(format!("• Source archive: {}", archive.name)));
                    }
                }
                ProgressStatus::Failed(error) => {
                    summary_lines.push(Line::from(vec![
                        Span::styled("❌ Restore failed!", 
                            Style::default().fg(Color::Red).add_modifier(Modifier::BOLD))
                    ]));
                    summary_lines.push(Line::from(""));
                    summary_lines.push(Line::from(vec![
                        Span::styled("Error: ", Style::default().add_modifier(Modifier::BOLD).fg(Color::Red)),
                        Span::raw(error),
                    ]));
                    summary_lines.push(Line::from(""));
                    summary_lines.push(Line::from(format!("• Items restored: {}/{}", 
                        progress.items_completed, progress.total_items)));
                    summary_lines.push(Line::from(format!("• Data processed: {}", 
                        format_bytes(progress.bytes_processed))));
                    
                    if progress.conflicts_resolved > 0 {
                        summary_lines.push(Line::from(format!("• Conflicts resolved: {}", progress.conflicts_resolved)));
                    }
                }
                _ => {
                    summary_lines.push(Line::from("Restore status unknown"));
                }
            }
        } else {
            summary_lines.push(Line::from("No restore progress information available"));
        }

        let summary_paragraph = Paragraph::new(summary_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Restore Results")
                    .title_alignment(Alignment::Center),
            )
            .alignment(Alignment::Left)
            .wrap(Wrap { trim: true });

        frame.render_widget(summary_paragraph, content_chunks[0]);

        // Actions/Next steps
        let is_success = state.restore_progress
            .as_ref()
            .map(|p| matches!(p.status, ProgressStatus::Completed))
            .unwrap_or(false);

        let actions_lines = if is_success {
            let mut lines = vec![
                Line::from(vec![
                    Span::styled("Next Steps:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Cyan))
                ]),
                Line::from(""),
                Line::from("• Your files have been restored successfully"),
                Line::from("• Check the restored files to ensure they're working correctly"),
                Line::from("• Update any absolute paths in configuration files if needed"),
                Line::from("• Restart applications that use the restored configurations"),
            ];

            // Add archive-specific advice
            if let Some(archive) = &state.selected_archive {
                lines.push(Line::from(""));
                match archive.mode {
                    crate::core::types::BackupMode::Complete => {
                        lines.push(Line::from(vec![
                            Span::styled("🔑 Complete Mode Restore:", Style::default().fg(Color::Red).add_modifier(Modifier::BOLD))
                        ]));
                        lines.push(Line::from("• SSH keys and credentials have been restored"));
                        lines.push(Line::from("• Verify SSH agent and GPG agent are working"));
                        lines.push(Line::from("• Check file permissions on sensitive files"));
                        lines.push(Line::from("• Test authentication to services and repositories"));
                    }
                    crate::core::types::BackupMode::Secure => {
                        lines.push(Line::from(vec![
                            Span::styled("🔰 Secure Mode Restore:", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))
                        ]));
                        lines.push(Line::from("• Configuration files have been restored"));
                        lines.push(Line::from("• You may need to re-setup credentials manually"));
                        lines.push(Line::from("• SSH keys and API tokens were not included"));
                    }
                }
            }

            lines
        } else {
            vec![
                Line::from(vec![
                    Span::styled("What to do next:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Yellow))
                ]),
                Line::from(""),
                Line::from("• Review the error message above"),
                Line::from("• Check available disk space in the restore location"),
                Line::from("• Verify write permissions for the restore paths"),
                Line::from("• Ensure the archive file is not corrupted"),
                Line::from("• Try the restore operation again"),
                Line::from(""),
                Line::from("If the problem persists, check the logs for more details."),
                Line::from("You may need to restore individual files manually."),
            ]
        };

        let actions_paragraph = Paragraph::new(actions_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title(if is_success { "Success" } else { "Troubleshooting" })
                    .title_alignment(Alignment::Center)
                    .style(Style::default().fg(if is_success { Color::Green } else { Color::Yellow })),
            )
            .alignment(Alignment::Left)
            .wrap(Wrap { trim: true });

        frame.render_widget(actions_paragraph, content_chunks[1]);

        // Footer
        let shortcuts = [
            ("Enter", "Return to Main Menu"),
            ("Q", "Quit Application"),
        ];

        render_footer(frame, chunks[2], &shortcuts, None);
    }
}