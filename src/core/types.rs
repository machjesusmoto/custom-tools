use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BackupMode {
    Secure,
    Complete,
}

impl BackupMode {
    pub fn as_str(&self) -> &'static str {
        match self {
            BackupMode::Secure => "secure",
            BackupMode::Complete => "complete",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SecurityLevel {
    Low,
    Medium,
    High,
}

impl SecurityLevel {
    pub fn color(&self) -> ratatui::style::Color {
        match self {
            SecurityLevel::Low => ratatui::style::Color::Green,
            SecurityLevel::Medium => ratatui::style::Color::Yellow,
            SecurityLevel::High => ratatui::style::Color::Red,
        }
    }
}

#[derive(Debug, Clone)]
pub struct BackupItem {
    pub name: String,
    pub path: PathBuf,
    pub category: String,
    pub description: String,
    pub security_level: SecurityLevel,
    pub warning: Option<String>,
    pub selected: bool,
    pub exists: bool,
    pub size: Option<u64>,
}

impl BackupItem {
    pub fn new(name: String, path: PathBuf, category: String, description: String) -> Self {
        Self {
            name,
            path,
            category,
            description,
            security_level: SecurityLevel::Low,
            warning: None,
            selected: false,
            exists: false,
            size: None,
        }
    }

    pub fn with_security_level(mut self, level: SecurityLevel) -> Self {
        self.security_level = level;
        self
    }

    pub fn with_warning(mut self, warning: String) -> Self {
        self.warning = Some(warning);
        self
    }
}

#[derive(Debug, Clone)]
pub struct BackupProgress {
    pub current_item: String,
    pub items_completed: usize,
    pub total_items: usize,
    pub bytes_processed: u64,
    pub total_bytes: u64,
    pub start_time: DateTime<Utc>,
    pub estimated_completion: Option<DateTime<Utc>>,
    pub status: ProgressStatus,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ProgressStatus {
    Preparing,
    Processing,
    Compressing,
    Encrypting,
    Finalizing,
    Completed,
    Failed(String),
}

impl ProgressStatus {
    pub fn as_str(&self) -> &str {
        match self {
            ProgressStatus::Preparing => "Preparing",
            ProgressStatus::Processing => "Processing",
            ProgressStatus::Compressing => "Compressing", 
            ProgressStatus::Encrypting => "Encrypting",
            ProgressStatus::Finalizing => "Finalizing",
            ProgressStatus::Completed => "Completed",
            ProgressStatus::Failed(_) => "Failed",
        }
    }

    pub fn color(&self) -> ratatui::style::Color {
        match self {
            ProgressStatus::Preparing | ProgressStatus::Processing 
            | ProgressStatus::Compressing | ProgressStatus::Encrypting 
            | ProgressStatus::Finalizing => ratatui::style::Color::Blue,
            ProgressStatus::Completed => ratatui::style::Color::Green,
            ProgressStatus::Failed(_) => ratatui::style::Color::Red,
        }
    }
}

impl Default for BackupProgress {
    fn default() -> Self {
        Self {
            current_item: String::new(),
            items_completed: 0,
            total_items: 0,
            bytes_processed: 0,
            total_bytes: 0,
            start_time: Utc::now(),
            estimated_completion: None,
            status: ProgressStatus::Preparing,
        }
    }
}

#[derive(Debug, Clone)]
pub struct ArchiveInfo {
    pub path: PathBuf,
    pub name: String,
    pub created: DateTime<Utc>,
    pub size: u64,
    pub mode: BackupMode,
    pub encrypted: bool,
    pub description: String,
    pub items: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct RestoreItem {
    pub name: String,
    pub original_path: PathBuf,
    pub restore_path: PathBuf,
    pub size: u64,
    pub selected: bool,
    pub conflicts: bool,
}

#[derive(Debug, Clone)]
pub struct RestoreProgress {
    pub current_item: String,
    pub items_completed: usize,
    pub total_items: usize,
    pub bytes_processed: u64,
    pub total_bytes: u64,
    pub start_time: DateTime<Utc>,
    pub status: ProgressStatus,
    pub conflicts_resolved: usize,
}

impl Default for RestoreProgress {
    fn default() -> Self {
        Self {
            current_item: String::new(),
            items_completed: 0,
            total_items: 0,
            bytes_processed: 0,
            total_bytes: 0,
            start_time: Utc::now(),
            status: ProgressStatus::Preparing,
            conflicts_resolved: 0,
        }
    }
}

#[derive(Debug, Clone)]
pub struct ValidationResult {
    pub success: bool,
    pub errors: Vec<String>,
    pub warnings: Vec<String>,
    pub total_size: u64,
    pub missing_items: Vec<String>,
}