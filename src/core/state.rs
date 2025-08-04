use crate::core::types::{
    ArchiveInfo, BackupItem, BackupMode, BackupProgress, RestoreItem, RestoreProgress,
    ValidationResult,
};
use crate::core::security::SecurePassword;
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq)]
pub enum AppState {
    MainMenu,
    BackupModeSelection,
    BackupItemSelection,
    BackupPasswordInput,
    BackupProgress,
    BackupComplete,
    RestoreArchiveSelection,
    RestorePasswordInput,
    RestoreItemSelection,
    RestoreProgress,
    RestoreComplete,
    Help,
    Error(String),
    Exit,
}

#[derive(Debug)]
pub struct AppStateManager {
    pub current_state: AppState,
    pub previous_state: Option<AppState>,
    
    // Backup state
    pub backup_mode: BackupMode,
    pub backup_items: Vec<BackupItem>,
    pub backup_password: Option<SecurePassword>,
    pub backup_progress: Option<BackupProgress>,
    pub backup_output_path: Option<PathBuf>,
    
    // Restore state
    pub available_archives: Vec<ArchiveInfo>,
    pub selected_archive: Option<ArchiveInfo>,
    pub restore_password: Option<SecurePassword>,
    pub restore_items: Vec<RestoreItem>,
    pub restore_progress: Option<RestoreProgress>,
    
    // UI state
    pub selected_item_index: usize,
    pub scroll_offset: usize,
    pub show_help: bool,
    pub validation_result: Option<ValidationResult>,
    pub status_message: Option<String>,
    pub error_message: Option<String>,
}

impl Default for AppStateManager {
    fn default() -> Self {
        Self {
            current_state: AppState::MainMenu,
            previous_state: None,
            backup_mode: BackupMode::Secure,
            backup_items: Vec::new(),
            backup_password: None,
            backup_progress: None,
            backup_output_path: None,
            available_archives: Vec::new(),
            selected_archive: None,
            restore_password: None,
            restore_items: Vec::new(),
            restore_progress: None,
            selected_item_index: 0,
            scroll_offset: 0,
            show_help: false,
            validation_result: None,
            status_message: None,
            error_message: None,
        }
    }
}

impl AppStateManager {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn transition_to(&mut self, new_state: AppState) {
        self.previous_state = Some(self.current_state.clone());
        self.current_state = new_state;
        
        // Reset UI state on transitions
        self.selected_item_index = 0;
        self.scroll_offset = 0;
        self.error_message = None;
    }

    pub fn go_back(&mut self) {
        if let Some(previous) = self.previous_state.take() {
            self.current_state = previous;
            self.selected_item_index = 0;
            self.scroll_offset = 0;
            self.error_message = None;
        }
    }

    pub fn reset_backup_state(&mut self) {
        self.backup_items.clear();
        self.backup_password = None;
        self.backup_progress = None;
        self.validation_result = None;
    }

    pub fn reset_restore_state(&mut self) {
        self.selected_archive = None;
        self.restore_password = None;
        self.restore_items.clear();
        self.restore_progress = None;
    }

    pub fn set_error(&mut self, error: String) {
        self.error_message = Some(error.clone());
        self.transition_to(AppState::Error(error));
    }

    pub fn set_status(&mut self, message: String) {
        self.status_message = Some(message);
    }

    pub fn clear_status(&mut self) {
        self.status_message = None;
    }

    pub fn get_selected_backup_items(&self) -> Vec<&BackupItem> {
        self.backup_items.iter().filter(|item| item.selected).collect()
    }

    pub fn get_selected_restore_items(&self) -> Vec<&RestoreItem> {
        self.restore_items.iter().filter(|item| item.selected).collect()
    }

    pub fn toggle_backup_item(&mut self, index: usize) {
        if let Some(item) = self.backup_items.get_mut(index) {
            item.selected = !item.selected;
        }
    }

    pub fn toggle_restore_item(&mut self, index: usize) {
        if let Some(item) = self.restore_items.get_mut(index) {
            item.selected = !item.selected;
        }
    }

    pub fn select_all_backup_items(&mut self, select: bool) {
        for item in &mut self.backup_items {
            item.selected = select;
        }
    }

    pub fn select_all_restore_items(&mut self, select: bool) {
        for item in &mut self.restore_items {
            item.selected = select;
        }
    }

    pub fn get_visible_backup_items(&self, height: usize) -> (usize, usize) {
        let total = self.backup_items.len();
        let start = self.scroll_offset;
        let end = (start + height).min(total);
        (start, end)
    }

    pub fn get_visible_restore_items(&self, height: usize) -> (usize, usize) {
        let total = self.restore_items.len();
        let start = self.scroll_offset;
        let end = (start + height).min(total);
        (start, end)
    }

    pub fn scroll_up(&mut self, amount: usize) {
        self.scroll_offset = self.scroll_offset.saturating_sub(amount);
    }

    pub fn scroll_down(&mut self, amount: usize, max_items: usize, visible_height: usize) {
        if max_items > visible_height {
            let max_scroll = max_items - visible_height;
            self.scroll_offset = (self.scroll_offset + amount).min(max_scroll);
        }
    }

    pub fn move_selection_up(&mut self, max_items: usize) {
        if max_items > 0 {
            self.selected_item_index = if self.selected_item_index == 0 {
                max_items - 1
            } else {
                self.selected_item_index - 1
            };
            
            // Adjust scroll if needed
            if self.selected_item_index < self.scroll_offset {
                self.scroll_offset = self.selected_item_index;
            }
        }
    }

    pub fn move_selection_down(&mut self, max_items: usize, visible_height: usize) {
        if max_items > 0 {
            self.selected_item_index = (self.selected_item_index + 1) % max_items;
            
            // Adjust scroll if needed
            if self.selected_item_index >= self.scroll_offset + visible_height {
                self.scroll_offset = self.selected_item_index - visible_height + 1;
            }
        }
    }

    pub fn page_up(&mut self, visible_height: usize) {
        let page_size = visible_height.saturating_sub(1).max(1);
        self.scroll_offset = self.scroll_offset.saturating_sub(page_size);
        self.selected_item_index = self.selected_item_index.saturating_sub(page_size);
    }

    pub fn page_down(&mut self, max_items: usize, visible_height: usize) {
        let page_size = visible_height.saturating_sub(1).max(1);
        
        if max_items > visible_height {
            let max_scroll = max_items - visible_height;
            self.scroll_offset = (self.scroll_offset + page_size).min(max_scroll);
        }
        
        self.selected_item_index = (self.selected_item_index + page_size).min(max_items - 1);
    }

    pub fn is_backup_ready(&self) -> bool {
        !self.get_selected_backup_items().is_empty()
    }

    pub fn is_restore_ready(&self) -> bool {
        self.selected_archive.is_some() && !self.get_selected_restore_items().is_empty()
    }

    pub fn get_backup_summary(&self) -> (usize, u64, usize) {
        let selected_items = self.get_selected_backup_items();
        let item_count = selected_items.len();
        let total_size = selected_items
            .iter()
            .filter_map(|item| item.size)
            .sum();
        let high_security_count = selected_items
            .iter()
            .filter(|item| matches!(item.security_level, crate::core::types::SecurityLevel::High))
            .count();
        
        (item_count, total_size, high_security_count)
    }

    pub fn get_restore_summary(&self) -> (usize, u64, usize) {
        let selected_items = self.get_selected_restore_items();
        let item_count = selected_items.len();
        let total_size = selected_items.iter().map(|item| item.size).sum();
        let conflicts = selected_items.iter().filter(|item| item.conflicts).count();
        
        (item_count, total_size, conflicts)
    }
}