use std::process::Command;
use std::env;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    
    // Check if we're in a CI environment where we might want to skip checks
    let skip_checks = env::var("SKIP_PREREQ_CHECKS").is_ok();
    if skip_checks {
        println!("cargo:warning=Skipping prerequisite checks (SKIP_PREREQ_CHECKS is set)");
        return;
    }

    println!("cargo:warning=Checking system prerequisites...");
    
    let mut missing = Vec::new();
    let mut warnings = Vec::new();
    
    // Required commands for basic functionality
    let required_commands = vec![
        ("bash", "Bash shell", "5.0"),
        ("tar", "GNU tar", "1.30"),
        ("gzip", "GNU gzip", "1.10"),
    ];
    
    // Optional but recommended commands
    let optional_commands = vec![
        ("gpg", "GPG encryption", "2.2"),
        ("shred", "Secure file deletion", "8.30"),
        ("pacman", "Arch package manager", "5.0"),
        ("flatpak", "Flatpak package manager", "1.0"),
        ("npm", "Node.js package manager", "6.0"),
        ("cargo", "Rust package manager", "1.60"),
        ("pip", "Python package manager", "20.0"),
    ];
    
    // Check required commands
    for (cmd, description, _min_version) in &required_commands {
        if !check_command(cmd) {
            missing.push(format!("  ❌ {} ({}) - REQUIRED", cmd, description));
        } else {
            println!("cargo:warning=  ✓ {} found", cmd);
        }
    }
    
    // Check optional commands
    for (cmd, description, _min_version) in &optional_commands {
        if !check_command(cmd) {
            warnings.push(format!("  ⚠️  {} ({}) - Optional, some features may not work", cmd, description));
        } else {
            println!("cargo:warning=  ✓ {} found", cmd);
        }
    }
    
    // Check for backup script files
    let scripts = vec![
        "backup-lib.sh",
        "backup-profile-enhanced.sh",
        "backup-profile-secure.sh",
        "backup-config.json",
    ];
    
    for script in &scripts {
        let path = std::path::Path::new(script);
        if !path.exists() {
            missing.push(format!("  ❌ {} - Required backup script not found", script));
        } else {
            println!("cargo:warning=  ✓ {} found", script);
        }
    }
    
    // Check terminal capabilities
    if env::var("TERM").is_err() {
        warnings.push("  ⚠️  TERM environment variable not set - Terminal UI may not work properly".to_string());
    }
    
    // Report results
    if !missing.is_empty() {
        eprintln!("\n🚨 MISSING REQUIRED PREREQUISITES:\n");
        for item in &missing {
            eprintln!("{}", item);
        }
        eprintln!("\nPlease install the missing prerequisites before building.");
        eprintln!("On Arch Linux: sudo pacman -S coreutils bash tar gzip");
        eprintln!("On Ubuntu/Debian: sudo apt-get install coreutils bash tar gzip");
        eprintln!("On macOS: brew install coreutils gnu-tar");
        panic!("Missing required prerequisites");
    }
    
    if !warnings.is_empty() {
        println!("\ncargo:warning=⚠️  OPTIONAL PREREQUISITES:");
        for warning in &warnings {
            println!("cargo:warning={}", warning);
        }
        println!("cargo:warning=");
        println!("cargo:warning=Some features may be limited without these tools.");
        println!("cargo:warning=For full functionality:");
        println!("cargo:warning=  Arch Linux: sudo pacman -S gnupg coreutils");
        println!("cargo:warning=  Ubuntu/Debian: sudo apt-get install gnupg coreutils");
        println!("cargo:warning=  macOS: brew install gnupg coreutils");
    }
    
    println!("cargo:warning=✅ All required prerequisites found!");
}

fn check_command(cmd: &str) -> bool {
    Command::new("which")
        .arg(cmd)
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}