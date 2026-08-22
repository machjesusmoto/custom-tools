use ratatui::layout::{Constraint, Direction, Layout};

use crate::core::state::AppStateManager;
use crate::core::types::ProgressStatus;
use crate::ui::components::{render_header, render_footer, render_progress_bar};

pub struct BackupProgressScreen;

impl BackupProgressScreen {
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
            "Backup in Progress",
            Some(&format!("Creating {} backup...", mode_name)),
        );

        // Progress content
        if let Some(progress) = &state.backup_progress {
            let percentage = if progress.total_items > 0 {
                (progress.items_completed as f64 / progress.total_items as f64) * 100.0
            } else {
                0.0
            };

            render_progress_bar(
                frame,
                chunks[1],
                &format!("Backup Progress - {}", progress.status.as_str()),
                percentage,
                &progress.current_item,
                progress.items_completed,
                progress.total_items,
            );
        } else {
            // Fallback if no progress data
            render_progress_bar(
                frame,
                chunks[1],
                "Initializing Backup...",
                0.0,
                "Preparing...",
                0,
                1,
            );
        }

        // Footer
        let shortcuts = [
            ("Ctrl+C", "Cancel"),
        ];

        let status = if let Some(progress) = &state.backup_progress {
            match &progress.status {
                ProgressStatus::Failed(error) => Some(error.as_str()),
                _ => None,
            }
        } else {
            None
        };

        render_footer(frame, chunks[2], &shortcuts, status);
    }
}