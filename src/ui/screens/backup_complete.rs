use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
};

use crate::core::state::AppStateManager;
use crate::core::types::ProgressStatus;
use crate::ui::components::{render_header, render_footer};
use crate::ui::terminal::format_bytes;

pub struct BackupCompleteScreen;

impl BackupCompleteScreen {
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
        let header_title = if let Some(progress) = &state.backup_progress {
            match progress.status {
                ProgressStatus::Completed => "Backup Completed Successfully",
                ProgressStatus::Failed(_) => "Backup Failed",
                _ => "Backup Status",
            }
        } else {
            "Backup Complete"
        };

        render_header(
            frame,
            chunks[0],
            header_title,
            Some("Your backup operation has finished"),
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
        
        if let Some(progress) = &state.backup_progress {
            match &progress.status {
                ProgressStatus::Completed => {
                    summary_lines.push(Line::from(vec![
                        Span::styled("✅ Backup completed successfully!", 
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
                    summary_lines.push(Line::from(format!("• Items processed: {}", progress.items_completed)));
                    summary_lines.push(Line::from(format!("• Data processed: {}", format_bytes(progress.bytes_processed))));
                    summary_lines.push(Line::from(format!("• Time taken: {}", duration_str)));
                    
                    if let Some(path) = &state.backup_output_path {
                        summary_lines.push(Line::from(format!("• Location: {}", path.display())));
                    }
                }
                ProgressStatus::Failed(error) => {
                    summary_lines.push(Line::from(vec![
                        Span::styled("❌ Backup failed!", 
                            Style::default().fg(Color::Red).add_modifier(Modifier::BOLD))
                    ]));
                    summary_lines.push(Line::from(""));
                    summary_lines.push(Line::from(vec![
                        Span::styled("Error: ", Style::default().add_modifier(Modifier::BOLD).fg(Color::Red)),
                        Span::raw(error),
                    ]));
                    summary_lines.push(Line::from(""));
                    summary_lines.push(Line::from(format!("• Items processed: {}/{}", 
                        progress.items_completed, progress.total_items)));
                    summary_lines.push(Line::from(format!("• Data processed: {}", 
                        format_bytes(progress.bytes_processed))));
                }
                _ => {
                    summary_lines.push(Line::from("Backup status unknown"));
                }
            }
        } else {
            summary_lines.push(Line::from("No backup progress information available"));
        }

        let summary_paragraph = Paragraph::new(summary_lines)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Backup Results")
                    .title_alignment(Alignment::Center),
            )
            .alignment(Alignment::Left)
            .wrap(Wrap { trim: true });

        frame.render_widget(summary_paragraph, content_chunks[0]);

        // Actions/Next steps
        let is_success = state.backup_progress
            .as_ref()
            .map(|p| matches!(p.status, ProgressStatus::Completed))
            .unwrap_or(false);

        let actions_lines = if is_success {
            vec![
                Line::from(vec![
                    Span::styled("Next Steps:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Cyan))
                ]),
                Line::from(""),
                Line::from("• Your backup has been created successfully"),
                Line::from("• Store the backup file in a secure location"),
                Line::from("• Consider creating regular backups to keep data current"),
                Line::from("• Test restore functionality periodically"),
                Line::from(""),
                if state.backup_mode == crate::core::types::BackupMode::Complete {
                    Line::from(vec![
                        Span::styled("⚠️ Security Reminder: ", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
                        Span::raw("This backup contains sensitive data and is encrypted."),
                    ])
                } else {
                    Line::from(vec![
                        Span::styled("ℹ️ Info: ", Style::default().fg(Color::Blue).add_modifier(Modifier::BOLD)),
                        Span::raw("This secure backup excludes sensitive credentials."),
                    ])
                },
                Line::from("Keep your backup password safe - it cannot be recovered!"),
            ]
        } else {
            vec![
                Line::from(vec![
                    Span::styled("What to do next:", Style::default().add_modifier(Modifier::BOLD).fg(Color::Yellow))
                ]),
                Line::from(""),
                Line::from("• Review the error message above"),
                Line::from("• Check available disk space"),
                Line::from("• Verify file permissions"),
                Line::from("• Try the backup operation again"),
                Line::from(""),
                Line::from("If the problem persists, check the logs for more details."),
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