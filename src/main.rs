use anyhow::Result;
use clap::Parser;
use log::{debug, error, info};
use crossterm::execute;

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
    
    // Set up panic handler to ensure terminal cleanup
    let original_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |panic_info| {
        // Try to cleanup terminal on panic
        let _ = crossterm::terminal::disable_raw_mode();
        let _ = execute!(
            std::io::stderr(),
            crossterm::terminal::LeaveAlternateScreen,
            crossterm::event::DisableMouseCapture
        );
        
        // Call the original panic handler
        original_hook(panic_info);
    }));
    
    // Run application with proper cleanup
    let result = run_app(&mut app, &mut terminal).await;
    
    // Always cleanup terminal, regardless of result
    if let Err(cleanup_err) = terminal.cleanup() {
        error!("Failed to cleanup terminal: {}", cleanup_err);
        // If we had a successful run but cleanup failed, return the cleanup error
        if result.is_ok() {
            return Err(cleanup_err);
        }
        // If we already had an error, log the cleanup error but return the original
    }
    
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
