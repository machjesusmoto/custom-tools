use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

use crate::core::types::{BackupItem, BackupMode, SecurityLevel};

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct BackupConfig {
    pub version: String,
    pub description: String,
    pub last_updated: String,
    pub backup_modes: HashMap<String, ModeConfig>,
    pub modern_configurations: ModernConfigurations,
    pub security_classifications: HashMap<String, SecurityClassification>,
    pub backup_strategies: HashMap<String, BackupStrategy>,
    pub validation: ValidationConfig,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ModeConfig {
    pub description: String,
    pub excludes_sensitive: bool,
    pub security_warning: Option<String>,
    pub categories: HashMap<String, Vec<String>>,
    pub exclusions: Vec<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ModernConfigurations {
    pub description: String,
    pub categories: HashMap<String, HashMap<String, ApplicationConfig>>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ApplicationConfig {
    pub paths: Vec<String>,
    pub description: String,
    pub security_level: String,
    pub category: String,
    pub warning: Option<String>,
    pub exclusions: Option<Vec<String>>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct SecurityClassification {
    pub description: String,
    pub requires_encryption: serde_json::Value, // Can be bool or string
    pub storage_warning: String,
    pub examples: Vec<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct BackupStrategy {
    pub description: String,
    pub mode: String,
    pub frequency: String,
    pub retention: String,
    pub encryption: Option<bool>,
    pub storage: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ValidationConfig {
    pub required_tools: Vec<String>,
    pub optional_tools: Vec<String>,
    pub minimum_disk_space: String,
    pub supported_compression: Vec<String>,
    pub supported_encryption: Vec<String>,
}

impl BackupConfig {
    pub fn load<P: AsRef<std::path::Path>>(path: P) -> Result<Self> {
        let specified_path = path.as_ref();
        
        // Try to find the config file in multiple locations
        let config_path = Self::find_config_file(specified_path)?;
        
        let content = fs::read_to_string(&config_path)
            .with_context(|| format!("Failed to read config file: {}", config_path.display()))?;
        
        let config: BackupConfig = serde_json::from_str(&content)
            .with_context(|| "Failed to parse config JSON")?;
        
        Ok(config)
    }
    
    /// Find the config file by checking multiple standard locations
    fn find_config_file(specified_path: &std::path::Path) -> Result<PathBuf> {
        // First try the exact path specified
        if specified_path.exists() {
            return Ok(specified_path.to_path_buf());
        }
        
        // Build list of potential locations to check
        let mut search_paths = Vec::new();
        
        // Current working directory
        let current_dir = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
        search_paths.push(current_dir.join(specified_path));
        
        // Home directory
        if let Some(home_dir) = dirs::home_dir() {
            search_paths.push(home_dir.join(specified_path));
            
            // Standard config locations in home directory
            search_paths.push(home_dir.join(".config").join("backup-manager").join(specified_path.file_name().unwrap_or(std::ffi::OsStr::new("backup-config.json"))));
            search_paths.push(home_dir.join(".backup-manager").join(specified_path.file_name().unwrap_or(std::ffi::OsStr::new("backup-config.json"))));
        }
        
        // System-wide config locations
        search_paths.push(PathBuf::from("/etc/backup-manager").join(specified_path.file_name().unwrap_or(std::ffi::OsStr::new("backup-config.json"))));
        search_paths.push(PathBuf::from("/usr/local/etc/backup-manager").join(specified_path.file_name().unwrap_or(std::ffi::OsStr::new("backup-config.json"))));
        
        // Project directory (for development)
        if let Ok(exe_path) = std::env::current_exe() {
            if let Some(exe_dir) = exe_path.parent() {
                // Check in the executable directory
                search_paths.push(exe_dir.join(specified_path));
                
                // Check in the project root (parent directories)
                let mut parent_dir = exe_dir;
                for _ in 0..5 { // Check up to 5 levels up
                    if let Some(parent) = parent_dir.parent() {
                        let project_config = parent.join(specified_path);
                        if project_config.exists() {
                            search_paths.push(project_config);
                        }
                        parent_dir = parent;
                    } else {
                        break;
                    }
                }
            }
        }
        
        // Try each location
        for path in &search_paths {
            if path.exists() {
                log::debug!("Found config file at: {}", path.display());
                return Ok(path.clone());
            }
        }
        
        // If none found, provide helpful error message
        let searched_locations: Vec<String> = search_paths.iter()
            .map(|p| p.display().to_string())
            .collect();
        
        anyhow::bail!(
            "Config file '{}' not found. Searched in:\n{}",
            specified_path.display(),
            searched_locations.join("\n")
        );
    }

    pub fn get_items_for_mode(&self, mode: &BackupMode) -> Vec<BackupItem> {
        let mode_str = mode.as_str();
        let mut items = Vec::new();

        // Get items from backup modes
        if let Some(mode_config) = self.backup_modes.get(mode_str) {
            for (category, paths) in &mode_config.categories {
                for path in paths {
                    let mut item = BackupItem::new(
                        path.clone(),
                        PathBuf::from(path),
                        category.clone(),
                        format!("Backup item from {} category", category),
                    );
                    
                    // Set security level based on path
                    item.security_level = self.determine_security_level(path);
                    
                    // Add warnings for sensitive items
                    if let Some(warning) = self.get_security_warning(path) {
                        item = item.with_warning(warning);
                    }
                    
                    items.push(item);
                }
            }
        }

        // Add items from modern configurations
        for (_, category_map) in &self.modern_configurations.categories {
            for (app_name, app_config) in category_map {
                // Skip high security items in secure mode
                if mode == &BackupMode::Secure && app_config.security_level == "high" {
                    continue;
                }

                for path in &app_config.paths {
                    let mut item = BackupItem::new(
                        format!("{} ({})", app_name, path),
                        PathBuf::from(path),
                        app_config.category.clone(),
                        app_config.description.clone(),
                    );

                    item.security_level = match app_config.security_level.as_str() {
                        "high" => SecurityLevel::High,
                        "medium" => SecurityLevel::Medium,
                        _ => SecurityLevel::Low,
                    };

                    if let Some(warning) = &app_config.warning {
                        item = item.with_warning(warning.clone());
                    }

                    items.push(item);
                }
            }
        }

        items
    }

    fn determine_security_level(&self, path: &str) -> SecurityLevel {
        // High security paths
        let high_security = [".ssh", ".gnupg", ".aws", ".kube", ".docker/config.json"];
        if high_security.iter().any(|&p| path.contains(p)) {
            return SecurityLevel::High;
        }

        // Medium security paths
        let medium_security = [".config/gh", ".config/docker", ".git-credentials"];
        if medium_security.iter().any(|&p| path.contains(p)) {
            return SecurityLevel::Medium;
        }

        SecurityLevel::Low
    }

    fn get_security_warning(&self, path: &str) -> Option<String> {
        if path.contains(".ssh") {
            Some("Contains SSH private keys and authentication data".to_string())
        } else if path.contains(".gnupg") {
            Some("Contains GPG private keys and trust database".to_string())
        } else if path.contains(".aws") {
            Some("Contains AWS credentials and configuration".to_string())
        } else if path.contains(".kube") {
            Some("Contains Kubernetes cluster credentials".to_string())
        } else if path.contains("git-credentials") {
            Some("Contains Git repository credentials".to_string())
        } else {
            None
        }
    }

    pub fn get_exclusions_for_mode(&self, mode: &BackupMode) -> Vec<String> {
        let mode_str = mode.as_str();
        if let Some(mode_config) = self.backup_modes.get(mode_str) {
            mode_config.exclusions.clone()
        } else {
            Vec::new()
        }
    }

    pub fn get_security_warning_for_mode(&self, mode: &BackupMode) -> Option<String> {
        let mode_str = mode.as_str();
        if let Some(mode_config) = self.backup_modes.get(mode_str) {
            mode_config.security_warning.clone()
        } else {
            None
        }
    }
}