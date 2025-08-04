use anyhow::{Context, Result};
use std::path::PathBuf;
use std::process::Stdio;
use tokio::process::Command as TokioCommand;
use tokio::io::{AsyncBufReadExt, BufReader};
use log::{debug, error, info, warn};

use crate::core::types::{
    ArchiveInfo, BackupItem, BackupMode, RestoreItem
};
use crate::core::security::SecurePassword;

pub struct BackupEngine {
    backup_lib_path: PathBuf,
}

impl BackupEngine {
    pub fn new() -> Result<Self> {
        // Find the appropriate backup script based on what's available
        let possible_paths = vec![
            PathBuf::from("./backup-profile-secure.sh"),
            PathBuf::from("./backup-profile-enhanced.sh"),
            PathBuf::from("/home/dtaylor/GitHub/custom-tools/backup-profile-secure.sh"),
            PathBuf::from("/home/dtaylor/GitHub/custom-tools/backup-profile-enhanced.sh"),
        ];
        
        let mut backup_lib_path = None;
        for path in &possible_paths {
            if path.exists() {
                backup_lib_path = Some(path.clone());
                info!("Found backup script at: {}", path.display());
                break;
            }
        }
        
        let backup_lib_path = backup_lib_path.ok_or_else(|| {
            anyhow::anyhow!(
                "No backup script found. Please ensure backup-profile-secure.sh or backup-profile-enhanced.sh is available."
            )
        })?;

        // Verify it's executable
        let metadata = std::fs::metadata(&backup_lib_path)?;
        let permissions = metadata.permissions();
        
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            if permissions.mode() & 0o111 == 0 {
                warn!("Backup script is not executable, attempting to make it executable");
                std::fs::set_permissions(&backup_lib_path, std::fs::Permissions::from_mode(0o755))?;
            }
        }

        Ok(Self { backup_lib_path })
    }

    pub async fn start_backup(
        &self,
        items: Vec<&BackupItem>,
        mode: &BackupMode,
        password: Option<&SecurePassword>,
        output_path: Option<&PathBuf>,
    ) -> Result<()> {
        info!("Starting backup operation in {} mode", mode.as_str());
        debug!("Backing up {} items", items.len());

        // Determine which script to use based on mode
        let script_path = if *mode == BackupMode::Secure {
            // Try to find the secure script
            let secure_paths = vec![
                PathBuf::from("./backup-profile-secure.sh"),
                PathBuf::from("/home/dtaylor/GitHub/custom-tools/backup-profile-secure.sh"),
            ];
            secure_paths.into_iter()
                .find(|p| p.exists())
                .unwrap_or(self.backup_lib_path.clone())
        } else {
            // Try to find the enhanced script for complete mode
            let enhanced_paths = vec![
                PathBuf::from("./backup-profile-enhanced.sh"),
                PathBuf::from("/home/dtaylor/GitHub/custom-tools/backup-profile-enhanced.sh"),
            ];
            enhanced_paths.into_iter()
                .find(|p| p.exists())
                .unwrap_or(self.backup_lib_path.clone())
        };

        info!("Using backup script: {}", script_path.display());

        // The backup scripts don't take individual item arguments
        // They backup predefined sets based on their configuration
        // We'll run the script with appropriate environment variables
        let mut command = TokioCommand::new("bash");
        command
            .arg(script_path)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .stdin(Stdio::piped());

        // Set output directory via environment variable
        if let Some(output) = output_path {
            command.env("BACKUP_DIR", output.to_string_lossy().as_ref());
        } else {
            // Default to current directory
            command.env("BACKUP_DIR", ".");
        }

        // Handle encryption - the scripts prompt for GPG encryption
        // For now, we'll set an environment variable to indicate if encryption is desired
        if password.is_some() {
            command.env("BACKUP_ENCRYPT", "yes");
            // Note: The actual scripts use GPG, not a simple password
            // This would need to be adapted to work with GPG key selection
        }

        debug!("Executing backup script");

        let mut child = command.spawn()
            .context("Failed to start backup process")?;

        // Monitor the process output
        if let Some(stdout) = child.stdout.take() {
            let reader = BufReader::new(stdout);
            let mut lines = reader.lines();

            while let Some(line) = lines.next_line().await? {
                debug!("Backup output: {}", line);
                
                // Parse progress information from the output
                // This would integrate with the backup-lib.sh progress reporting
                if line.contains("Processing:") {
                    // Update progress based on script output
                }
            }
        }

        // Wait for the process to complete
        let exit_status = child.wait().await?;

        if exit_status.success() {
            info!("Backup completed successfully");
            Ok(())
        } else {
            let error_msg = format!("Backup process failed with exit code: {:?}", exit_status.code());
            error!("{}", error_msg);
            Err(anyhow::anyhow!(error_msg))
        }
    }

    pub async fn start_restore(
        &self,
        archive: &ArchiveInfo,
        items: Vec<&RestoreItem>,
        password: Option<&SecurePassword>,
    ) -> Result<()> {
        info!("Starting restore operation from archive: {}", archive.name);
        debug!("Restoring {} items", items.len());

        // Prepare arguments for the restore script
        let mut args = vec![
            "bash".to_string(),
            self.backup_lib_path.to_string_lossy().to_string(),
            "restore_backup".to_string(),
            archive.path.to_string_lossy().to_string(),
        ];

        // Add decryption flag if password is provided
        if password.is_some() {
            args.push("--decrypt".to_string());
        }

        // Add selective restore items
        for item in &items {
            args.push("--item".to_string());
            args.push(item.name.clone());
        }

        debug!("Executing restore command with {} arguments", args.len());

        // Execute the restore command
        let mut command = TokioCommand::new(&args[0]);
        command
            .args(&args[1..])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        // Set password via environment variable if provided
        if let Some(pwd) = password {
            command.env("RESTORE_PASSWORD", String::from_utf8_lossy(pwd.as_bytes()).as_ref());
        }

        let mut child = command.spawn()
            .context("Failed to start restore process")?;

        // Monitor the process output
        if let Some(stdout) = child.stdout.take() {
            let reader = BufReader::new(stdout);
            let mut lines = reader.lines();

            while let Some(line) = lines.next_line().await? {
                debug!("Restore output: {}", line);
                
                // Parse progress information from the output
                if line.contains("Restoring:") {
                    // Update progress based on script output
                }
            }
        }

        // Wait for the process to complete
        let exit_status = child.wait().await?;

        if exit_status.success() {
            info!("Restore completed successfully");
            Ok(())
        } else {
            let error_msg = format!("Restore process failed with exit code: {:?}", exit_status.code());
            error!("{}", error_msg);
            Err(anyhow::anyhow!(error_msg))
        }
    }

    pub async fn list_archives(&self) -> Result<Vec<ArchiveInfo>> {
        info!("Scanning for available backup archives");

        // This would typically scan a backup directory for archive files
        // For now, we'll return a mock list to demonstrate functionality
        let mut archives = Vec::new();

        // Look for backup files in common locations
        let search_paths = vec![
            PathBuf::from("."),
            PathBuf::from("./backups"),
            dirs::home_dir().map(|h| h.join("backups")).unwrap_or_else(|| PathBuf::from(".")),
        ];

        for search_path in search_paths {
            if search_path.exists() && search_path.is_dir() {
                if let Ok(entries) = std::fs::read_dir(&search_path) {
                    for entry in entries.flatten() {
                        let path = entry.path();
                        if let Some(extension) = path.extension() {
                            let ext = extension.to_string_lossy().to_lowercase();
                            if ext == "gz" || ext == "xz" || ext == "tar" {
                                if let Some(file_name) = path.file_name() {
                                    let name = file_name.to_string_lossy().to_string();
                                    
                                    // Determine if encrypted based on filename patterns
                                    let encrypted = name.contains("encrypted") || name.contains("complete");
                                    
                                    // Determine backup mode from filename
                                    let mode = if name.contains("secure") {
                                        BackupMode::Secure
                                    } else {
                                        BackupMode::Complete
                                    };

                                    let size = entry.metadata()
                                        .map(|m| m.len())
                                        .unwrap_or(0);

                                    let created = entry.metadata()
                                        .and_then(|m| m.created())
                                        .map(|t| chrono::DateTime::from(t))
                                        .unwrap_or_else(|_| chrono::Utc::now());

                                    let archive = ArchiveInfo {
                                        path: path.clone(),
                                        name,
                                        created,
                                        size,
                                        mode,
                                        encrypted,
                                        description: format!("Backup archive from {}", 
                                            created.format("%Y-%m-%d %H:%M")),
                                        items: Vec::new(), // Would be populated by inspecting the archive
                                    };

                                    archives.push(archive);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Sort archives by creation date (newest first)
        archives.sort_by(|a, b| b.created.cmp(&a.created));

        info!("Found {} backup archives", archives.len());
        Ok(archives)
    }

    pub async fn list_archive_contents(
        &self,
        archive: &ArchiveInfo,
        password: Option<&SecurePassword>,
    ) -> Result<Vec<RestoreItem>> {
        info!("Listing contents of archive: {}", archive.name);

        // Prepare arguments to list archive contents
        let mut args = vec![
            "bash".to_string(),
            self.backup_lib_path.to_string_lossy().to_string(),
            "list_archive".to_string(),
            archive.path.to_string_lossy().to_string(),
        ];

        if password.is_some() {
            args.push("--decrypt".to_string());
        }

        let mut command = TokioCommand::new(&args[0]);
        command
            .args(&args[1..])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        // Set password via environment variable if provided
        if let Some(pwd) = password {
            command.env("LIST_PASSWORD", String::from_utf8_lossy(pwd.as_bytes()).as_ref());
        }

        let output = command.output().await
            .context("Failed to list archive contents")?;

        if !output.status.success() {
            let error = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!("Failed to list archive contents: {}", error));
        }

        // Parse the output to create RestoreItem list
        let contents = String::from_utf8_lossy(&output.stdout);
        let mut items = Vec::new();

        for line in contents.lines() {
            if !line.trim().is_empty() {
                // Parse each line to extract file information
                // Format: "path|size|original_path"
                let parts: Vec<&str> = line.split('|').collect();
                if parts.len() >= 3 {
                    let name = parts[0].to_string();
                    let size = parts[1].parse::<u64>().unwrap_or(0);
                    let original_path = PathBuf::from(parts[2]);
                    
                    // Determine restore path (usually the same as original)
                    let home_dir = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"));
                    let restore_path = if original_path.is_absolute() {
                        original_path.clone()
                    } else {
                        home_dir.join(&original_path)
                    };

                    // Check for conflicts (file already exists)
                    let conflicts = restore_path.exists();

                    let item = RestoreItem {
                        name,
                        original_path,
                        restore_path,
                        size,
                        selected: false,
                        conflicts,
                    };

                    items.push(item);
                }
            }
        }

        info!("Found {} items in archive", items.len());
        Ok(items)
    }

    pub async fn validate_tools(&self) -> Result<Vec<String>> {
        let mut missing_tools = Vec::new();
        let required_tools = vec!["tar", "gzip", "sha256sum", "find"];
        let optional_tools = vec!["gpg", "pv", "xz"];

        for tool in required_tools {
            if !self.check_tool_available(tool).await {
                missing_tools.push(format!("Required tool missing: {}", tool));
            }
        }

        for tool in optional_tools {
            if !self.check_tool_available(tool).await {
                warn!("Optional tool missing: {} (some features may be unavailable)", tool);
            }
        }

        Ok(missing_tools)
    }

    async fn check_tool_available(&self, tool: &str) -> bool {
        TokioCommand::new("which")
            .arg(tool)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .await
            .map(|status| status.success())
            .unwrap_or(false)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_backup_engine_creation() {
        // This test would need the backup-lib.sh file to exist
        // In a real implementation, you might mock this or use a test fixture
    }

    #[tokio::test]
    async fn test_tool_validation() {
        let engine = BackupEngine::new().unwrap();
        let missing = engine.validate_tools().await.unwrap();
        
        // Should have tar and gzip on most Unix systems
        assert!(engine.check_tool_available("tar").await);
    }
}