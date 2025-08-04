use ratatui::{
    layout::{Constraint, Direction, Layout},
    Frame,
};

use crate::core::state::AppStateManager;
use crate::core::types::ProgressStatus;
use crate::ui::components::{render_header, render_footer, render_progress_bar};

pub struct RestoreProgressScreen;

impl RestoreProgressScreen {
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
            "Restore in Progress",
            Some(&format!("Restoring from archive: {}", archive_name)),
        );

        // Progress content
        if let Some(progress) = &state.restore_progress {
            let percentage = if progress.total_items > 0 {
                (progress.items_completed as f64 / progress.total_items as f64) * 100.0
            } else {
                0.0
            };

            render_progress_bar(
                frame,
                chunks[1],
                &format!("Restore Progress - {}", progress.status.as_str()),
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
                "Initializing Restore...",
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

        let status = if let Some(progress) = &state.restore_progress {
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