use anyhow::{Context, Result};
use crossterm::event::{Event, KeyCode, KeyEvent, KeyModifiers};
use log::{debug, error, info, warn};
use ratatui::backend::Backend;
use std::path::PathBuf;

use crate::backend::BackupEngine;
use crate::core::config::BackupConfig;
use crate::core::state::{AppState, AppStateManager};
use crate::core::types::{BackupItem, BackupMode, RestoreItem};
use crate::ui::screens::{
    BackupCompleteScreen, BackupItemSelectionScreen, BackupModeSelectionScreen,
    BackupPasswordScreen, BackupProgressScreen, ErrorScreen, HelpScreen, MainMenuScreen,
    RestoreArchiveSelectionScreen, RestoreCompleteScreen, RestoreItemSelectionScreen,
    RestorePasswordScreen, RestoreProgressScreen,
};

pub struct AppConfig {
    pub backup_config: BackupConfig,
    pub output_path: Option<PathBuf>,
}

impl AppConfig {
    pub fn load(config_path: &str, output_path: Option<String>) -> Result<Self> {
        let backup_config = BackupConfig::load(config_path)
            .with_context(|| "Failed to load backup configuration")?;
        
        let output_path = output_path.map(PathBuf::from);
        
        Ok(Self {
            backup_config,
            output_path,
        })
    }
}

pub struct App {
    pub config: AppConfig,
    pub state: AppStateManager,
    pub backend: BackupEngine,
    
    // UI screens
    main_menu: MainMenuScreen,
    backup_mode_selection: BackupModeSelectionScreen,
    backup_item_selection: BackupItemSelectionScreen,
    backup_password: BackupPasswordScreen,
    backup_progress: BackupProgressScreen,
    backup_complete: BackupCompleteScreen,
    restore_archive_selection: RestoreArchiveSelectionScreen,
    restore_password: RestorePasswordScreen,
    restore_item_selection: RestoreItemSelectionScreen,
    restore_progress: RestoreProgressScreen,
    restore_complete: RestoreCompleteScreen,
    help: HelpScreen,
    error: ErrorScreen,
}

impl App {
    pub fn new(config: AppConfig) -> Result<Self> {
        let mut state = AppStateManager::new();
        
        // Set initial output path if provided
        if let Some(ref path) = config.output_path {
            state.backup_output_path = Some(path.clone());
        }
        
        let backend = BackupEngine::new()?;
        
        Ok(Self {
            config,
            state,
            backend,
            main_menu: MainMenuScreen::new(),
            backup_mode_selection: BackupModeSelectionScreen::new(),
            backup_item_selection: BackupItemSelectionScreen::new(),
            backup_password: BackupPasswordScreen::new(),
            backup_progress: BackupProgressScreen::new(),
            backup_complete: BackupCompleteScreen::new(),
            restore_archive_selection: RestoreArchiveSelectionScreen::new(),
            restore_password: RestorePasswordScreen::new(),
            restore_item_selection: RestoreItemSelectionScreen::new(),
            restore_progress: RestoreProgressScreen::new(),
            restore_complete: RestoreCompleteScreen::new(),
            help: HelpScreen::new(),
            error: ErrorScreen::new(),
        })
    }

    pub fn render(&mut self, frame: &mut ratatui::Frame) {
        match &self.state.current_state {
            AppState::MainMenu => {
                self.main_menu.render(frame, &self.state);
            }
            AppState::BackupModeSelection => {
                self.backup_mode_selection.render(frame, &self.state);
            }
            AppState::BackupItemSelection => {
                self.backup_item_selection.render(frame, &self.state);
            }
            AppState::BackupPasswordInput => {
                self.backup_password.render(frame, &self.state);
            }
            AppState::BackupProgress => {
                self.backup_progress.render(frame, &self.state);
            }
            AppState::BackupComplete => {
                self.backup_complete.render(frame, &self.state);
            }
            AppState::RestoreArchiveSelection => {
                self.restore_archive_selection.render(frame, &self.state);
            }
            AppState::RestorePasswordInput => {
                self.restore_password.render(frame, &self.state);
            }
            AppState::RestoreItemSelection => {
                self.restore_item_selection.render(frame, &self.state);
            }
            AppState::RestoreProgress => {
                self.restore_progress.render(frame, &self.state);
            }
            AppState::RestoreComplete => {
                self.restore_complete.render(frame, &self.state);
            }
            AppState::Help => {
                self.help.render(frame, &self.state);
            }
            AppState::Error(_) => {
                self.error.render(frame, &self.state);
            }
            AppState::Exit => {
                // This state should trigger app exit
            }
        }
    }

    pub async fn handle_event(&mut self, event: Event) -> Result<bool> {
        match event {
            Event::Key(key) => {
                // Global key handlers
                if key.modifiers.contains(KeyModifiers::CONTROL) {
                    match key.code {
                        KeyCode::Char('c') => {
                            info!("Received Ctrl+C, exiting application");
                            return Ok(true); // Exit
                        }
                        KeyCode::Char('h') => {
                            self.state.transition_to(AppState::Help);
                            return Ok(false);
                        }
                        _ => {}
                    }
                }

                self.handle_key_event(key).await?;
                
                // Check if we should exit after handling the key event
                if matches!(self.state.current_state, AppState::Exit) {
                    info!("Application state transitioned to Exit, shutting down");
                    return Ok(true); // Exit
                }
            }
            Event::Resize(_, _) => {
                // Handle terminal resize
                debug!("Terminal resized");
            }
            _ => {}
        }
        
        Ok(false) // Continue running
    }

    async fn handle_key_event(&mut self, key: KeyEvent) -> Result<()> {
        match &self.state.current_state {
            AppState::MainMenu => {
                self.handle_main_menu_key(key).await?;
            }
            AppState::BackupModeSelection => {
                self.handle_backup_mode_selection_key(key).await?;
            }
            AppState::BackupItemSelection => {
                self.handle_backup_item_selection_key(key).await?;
            }
            AppState::BackupPasswordInput => {
                self.handle_backup_password_key(key).await?;
            }
            AppState::BackupProgress => {
                self.handle_backup_progress_key(key).await?;
            }
            AppState::BackupComplete => {
                self.handle_backup_complete_key(key).await?;
            }
            AppState::RestoreArchiveSelection => {
                self.handle_restore_archive_selection_key(key).await?;
            }
            AppState::RestorePasswordInput => {
                self.handle_restore_password_key(key).await?;
            }
            AppState::RestoreItemSelection => {
                self.handle_restore_item_selection_key(key).await?;
            }
            AppState::RestoreProgress => {
                self.handle_restore_progress_key(key).await?;
            }
            AppState::RestoreComplete => {
                self.handle_restore_complete_key(key).await?;
            }
            AppState::Help => {
                self.handle_help_key(key).await?;
            }
            AppState::Error(_) => {
                self.handle_error_key(key).await?;
            }
            AppState::Exit => {
                // Should not reach here
            }
        }
        
        Ok(())
    }

    async fn handle_main_menu_key(&mut self, key: KeyEvent) -> Result<()> {
        // Handle menu navigation and selection
        if let Some(selected_key) = self.main_menu.handle_key(key) {
            match selected_key {
                '1' => {
                    self.state.transition_to(AppState::BackupModeSelection);
                }
                '2' => {
                    self.load_available_archives().await?;
                    self.state.transition_to(AppState::RestoreArchiveSelection);
                }
                'q' => {
                    info!("User requested exit from main menu");
                    self.state.transition_to(AppState::Exit);
                }
                _ => {}
            }
        } else {
            // Handle direct key presses (for backward compatibility)
            match key.code {
                KeyCode::Char('b') | KeyCode::Char('B') => {
                    self.state.transition_to(AppState::BackupModeSelection);
                }
                KeyCode::Char('r') | KeyCode::Char('R') => {
                    self.load_available_archives().await?;
                    self.state.transition_to(AppState::RestoreArchiveSelection);
                }
                KeyCode::Char('Q') | KeyCode::Esc => {
                    info!("User requested exit from main menu");
                    self.state.transition_to(AppState::Exit);
                }
                _ => {}
            }
        }
        Ok(())
    }

    async fn handle_backup_mode_selection_key(&mut self, key: KeyEvent) -> Result<()> {
        // Handle menu navigation and selection
        if let Some(selected_key) = self.backup_mode_selection.handle_key(key) {
            match selected_key {
                '1' => {
                    self.state.backup_mode = BackupMode::Secure;
                    self.load_backup_items().await?;
                    self.state.transition_to(AppState::BackupItemSelection);
                }
                '2' => {
                    self.state.backup_mode = BackupMode::Complete;
                    self.load_backup_items().await?;
                    self.state.transition_to(AppState::BackupItemSelection);
                }
                _ => {}
            }
        } else {
            // Handle direct key presses (for backward compatibility)
            match key.code {
                KeyCode::Char('s') | KeyCode::Char('S') => {
                    self.state.backup_mode = BackupMode::Secure;
                    self.load_backup_items().await?;
                    self.state.transition_to(AppState::BackupItemSelection);
                }
                KeyCode::Char('c') | KeyCode::Char('C') => {
                    self.state.backup_mode = BackupMode::Complete;
                    self.load_backup_items().await?;
                    self.state.transition_to(AppState::BackupItemSelection);
                }
                KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                    self.state.go_back();
                }
                _ => {}
            }
        }
        Ok(())
    }

    async fn handle_backup_item_selection_key(&mut self, key: KeyEvent) -> Result<()> {
        let item_count = self.state.backup_items.len();
        
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                self.state.move_selection_up(item_count);
            }
            KeyCode::Down | KeyCode::Char('j') => {
                self.state.move_selection_down(item_count, 10); // Assume 10 visible items
            }
            KeyCode::PageUp => {
                self.state.page_up(10);
            }
            KeyCode::PageDown => {
                self.state.page_down(item_count, 10);
            }
            KeyCode::Char(' ') => {
                self.state.toggle_backup_item(self.state.selected_item_index);
            }
            KeyCode::Char('a') => {
                self.state.select_all_backup_items(true);
            }
            KeyCode::Char('n') => {
                self.state.select_all_backup_items(false);
            }
            KeyCode::Enter => {
                if self.state.is_backup_ready() {
                    if self.state.backup_mode == BackupMode::Complete {
                        self.state.transition_to(AppState::BackupPasswordInput);
                    } else {
                        self.start_backup().await?;
                    }
                }
            }
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                self.state.go_back();
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_backup_password_key(&mut self, key: KeyEvent) -> Result<()> {
        // Password input is handled by the password screen
        match self.backup_password.handle_key(key) {
            Some(password) => {
                self.state.backup_password = Some(password);
                self.start_backup().await?;
            }
            None => {
                if key.code == KeyCode::Esc {
                    self.state.go_back();
                }
            }
        }
        Ok(())
    }

    async fn handle_backup_progress_key(&mut self, _key: KeyEvent) -> Result<()> {
        // Progress screen is mostly read-only
        // Could add cancellation support here
        Ok(())
    }

    async fn handle_backup_complete_key(&mut self, key: KeyEvent) -> Result<()> {
        match key.code {
            KeyCode::Enter | KeyCode::Char(' ') => {
                self.state.reset_backup_state();
                self.state.transition_to(AppState::MainMenu);
            }
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                self.state.transition_to(AppState::Exit);
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_restore_archive_selection_key(&mut self, key: KeyEvent) -> Result<()> {
        let archive_count = self.state.available_archives.len();
        
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                self.state.move_selection_up(archive_count);
            }
            KeyCode::Down | KeyCode::Char('j') => {
                self.state.move_selection_down(archive_count, 10);
            }
            KeyCode::Enter => {
                if let Some(archive) = self.state.available_archives.get(self.state.selected_item_index) {
                    self.state.selected_archive = Some(archive.clone());
                    if archive.encrypted {
                        self.state.transition_to(AppState::RestorePasswordInput);
                    } else {
                        self.load_restore_items().await?;
                        self.state.transition_to(AppState::RestoreItemSelection);
                    }
                }
            }
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                self.state.go_back();
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_restore_password_key(&mut self, key: KeyEvent) -> Result<()> {
        match self.restore_password.handle_key(key) {
            Some(password) => {
                self.state.restore_password = Some(password);
                self.load_restore_items().await?;
                self.state.transition_to(AppState::RestoreItemSelection);
            }
            None => {
                if key.code == KeyCode::Esc {
                    self.state.go_back();
                }
            }
        }
        Ok(())
    }

    async fn handle_restore_item_selection_key(&mut self, key: KeyEvent) -> Result<()> {
        let item_count = self.state.restore_items.len();
        
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                self.state.move_selection_up(item_count);
            }
            KeyCode::Down | KeyCode::Char('j') => {
                self.state.move_selection_down(item_count, 10);
            }
            KeyCode::Char(' ') => {
                self.state.toggle_restore_item(self.state.selected_item_index);
            }
            KeyCode::Char('a') => {
                self.state.select_all_restore_items(true);
            }
            KeyCode::Char('n') => {
                self.state.select_all_restore_items(false);
            }
            KeyCode::Enter => {
                if self.state.is_restore_ready() {
                    self.start_restore().await?;
                }
            }
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                self.state.go_back();
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_restore_progress_key(&mut self, _key: KeyEvent) -> Result<()> {
        Ok(())
    }

    async fn handle_restore_complete_key(&mut self, key: KeyEvent) -> Result<()> {
        match key.code {
            KeyCode::Enter | KeyCode::Char(' ') => {
                self.state.reset_restore_state();
                self.state.transition_to(AppState::MainMenu);
            }
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                self.state.transition_to(AppState::Exit);
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_help_key(&mut self, key: KeyEvent) -> Result<()> {
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                self.state.go_back();
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_error_key(&mut self, key: KeyEvent) -> Result<()> {
        match key.code {
            KeyCode::Enter | KeyCode::Esc | KeyCode::Char(' ') => {
                // Clear the error and go back to the previous state
                self.state.error_message = None;
                self.state.go_back();
                // Force a full redraw by resetting the terminal
                // This helps fix screen corruption issues
                debug!("Returning from error state to: {:?}", self.state.current_state);
            }
            _ => {}
        }
        Ok(())
    }

    async fn load_backup_items(&mut self) -> Result<()> {
        info!("Loading backup items for mode: {:?}", self.state.backup_mode);
        
        self.state.backup_items = self.config.backup_config.get_items_for_mode(&self.state.backup_mode);
        
        // Validate items exist and get their sizes
        for item in &mut self.state.backup_items {
            let home_dir = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"));
            let full_path = home_dir.join(&item.path);
            item.exists = full_path.exists();
            
            if item.exists {
                item.size = Self::get_path_size(&full_path).ok();
            }
        }
        
        debug!("Loaded {} backup items", self.state.backup_items.len());
        Ok(())
    }

    async fn load_available_archives(&mut self) -> Result<()> {
        info!("Loading available archives");
        
        // This would typically scan for archive files in the backup directory
        // For now, we'll use the backend to get available archives
        self.state.available_archives = self.backend.list_archives().await?;
        
        debug!("Found {} available archives", self.state.available_archives.len());
        Ok(())
    }

    async fn load_restore_items(&mut self) -> Result<()> {
        if let Some(archive) = &self.state.selected_archive {
            info!("Loading restore items from archive: {}", archive.name);
            
            self.state.restore_items = self.backend
                .list_archive_contents(archive, self.state.restore_password.as_ref())
                .await?;
            
            debug!("Loaded {} restore items", self.state.restore_items.len());
        }
        Ok(())
    }

    async fn start_backup(&mut self) -> Result<()> {
        info!("Starting backup operation");
        
        if !self.state.is_backup_ready() {
            warn!("No items selected for backup");
            self.state.set_error("No items selected for backup".to_string());
            return Ok(());
        }

        // Collect all data we need before making mutable calls
        let selected_items: Vec<BackupItem> = self.state.get_selected_backup_items().into_iter().cloned().collect();
        let backup_mode = self.state.backup_mode.clone();
        let backup_password = self.state.backup_password.clone();
        let backup_output_path = self.state.backup_output_path.clone();
        
        self.state.transition_to(AppState::BackupProgress);
        
        // Start backup in background
        let selected_item_refs: Vec<&BackupItem> = selected_items.iter().collect();
        let result = self.backend.start_backup(
            selected_item_refs,
            &backup_mode,
            backup_password.as_ref(),
            backup_output_path.as_ref(),
        ).await;

        match result {
            Ok(_) => {
                info!("Backup completed successfully");
                self.state.transition_to(AppState::BackupComplete);
            }
            Err(e) => {
                error!("Backup failed: {}", e);
                self.state.set_error(format!("Backup failed: {}", e));
            }
        }
        
        Ok(())
    }

    async fn start_restore(&mut self) -> Result<()> {
        info!("Starting restore operation");
        
        if !self.state.is_restore_ready() {
            warn!("No items selected for restore");
            self.state.set_error("No items selected for restore".to_string());
            return Ok(());
        }

        if let Some(archive) = self.state.selected_archive.clone() {
            // Collect all data we need before making mutable calls
            let selected_items: Vec<RestoreItem> = self.state.get_selected_restore_items().into_iter().cloned().collect();
            let restore_password = self.state.restore_password.clone();
            
            self.state.transition_to(AppState::RestoreProgress);
            
            let selected_item_refs: Vec<&RestoreItem> = selected_items.iter().collect();
            let result = self.backend.start_restore(
                &archive,
                selected_item_refs,
                restore_password.as_ref(),
            ).await;

            match result {
                Ok(_) => {
                    info!("Restore completed successfully");
                    self.state.transition_to(AppState::RestoreComplete);
                }
                Err(e) => {
                    error!("Restore failed: {}", e);
                    self.state.set_error(format!("Restore failed: {}", e));
                }
            }
        }
        
        Ok(())
    }

    fn get_path_size(path: &std::path::Path) -> Result<u64> {
        if path.is_file() {
            Ok(path.metadata()?.len())
        } else if path.is_dir() {
            let mut total_size = 0;
            for entry in std::fs::read_dir(path)? {
                let entry = entry?;
                let entry_path = entry.path();
                if entry_path.is_file() {
                    total_size += entry.metadata()?.len();
                } else if entry_path.is_dir() {
                    total_size += Self::get_path_size(&entry_path)?;
                }
            }
            Ok(total_size)
        } else {
            Ok(0)
        }
    }
}