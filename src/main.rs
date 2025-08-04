use anyhow::Result;
use clap::Parser;
use log::{debug, error, info};

mod core;
mod ui;
mod backend;

use core::app::{App, AppConfig};
use ui::terminal::Terminal;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to backup configuration file
    #[arg(short, long, default_value = "backup-config.json")]
    config: String,
    
    /// Enable debug logging
    #[arg(short, long)]
    debug: bool,
    
    /// Backup destination directory
    #[arg(short = 'o', long)]
    output: Option<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    // Initialize logging
    let log_level = if cli.debug { "debug" } else { "info" };
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or(log_level))
        .init();
    
    info!("Starting Backup UI v{}", env!("CARGO_PKG_VERSION"));
    debug!("Debug logging enabled");
    
    // Load configuration
    let config = AppConfig::load(&cli.config, cli.output)?;
    debug!("Configuration loaded successfully");
    
    // Initialize application
    let mut app = App::new(config)?;
    debug!("Application initialized");
    
    // Initialize terminal
    let mut terminal = Terminal::new()?;
    debug!("Terminal initialized");
    
    // Run application
    let result = run_app(&mut app, &mut terminal).await;
    
    // Cleanup terminal
    terminal.cleanup()?;
    
    match result {
        Ok(_) => {
            info!("Application exited successfully");
            Ok(())
        }
        Err(e) => {
            error!("Application error: {}", e);
            Err(e)
        }
    }
}

async fn run_app(app: &mut App, terminal: &mut Terminal) -> Result<()> {
    loop {
        // Draw UI
        terminal.draw(|f| app.render(f))?;
        
        // Handle events
        if let Some(event) = terminal.next_event().await? {
            if app.handle_event(event).await? {
                break; // Exit requested
            }
        }
    }
    
    Ok(())
}
