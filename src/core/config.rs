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
        let content = fs::read_to_string(&path)
            .with_context(|| format!("Failed to read config file: {}", path.as_ref().display()))?;
        
        let config: BackupConfig = serde_json::from_str(&content)
            .with_context(|| "Failed to parse config JSON")?;
        
        Ok(config)
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