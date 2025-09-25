use anyhow::Result;
use chrono::Local;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyModifiers},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::{Backend, CrosstermBackend},
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, List, ListItem, Paragraph, Wrap},
    Frame, Terminal,
};
use serde::{Deserialize, Serialize};
use std::{
    io,
    path::PathBuf,
    process::Command,
    time::{Duration, Instant},
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MenuItem {
    pub name: String,
    pub description: String,
    pub command: String,
    pub category: String,
    pub shortcut: Option<char>,
    pub dangerous: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MenuConfig {
    pub title: String,
    pub version: String,
    pub items: Vec<MenuItem>,
}

pub struct App {
    pub items: Vec<MenuItem>,
    pub selected: usize,
    pub status_message: String,
    pub last_command_output: Vec<String>,
    pub show_output: bool,
    pub filter: String,
    pub filtered_items: Vec<usize>,
    pub config: MenuConfig,
}

impl App {
    pub fn new() -> Result<Self> {
        let config = Self::load_config()?;
        let filtered_items: Vec<usize> = (0..config.items.len()).collect();
        
        Ok(App {
            items: config.items.clone(),
            selected: 0,
            status_message: String::from("Ready. Press 'h' for help."),
            last_command_output: Vec::new(),
            show_output: false,
            filter: String::new(),
            filtered_items,
            config,
        })
    }

    fn load_config() -> Result<MenuConfig> {
        // Default configuration with all our disaster recovery tools
        let default_config = MenuConfig {
            title: String::from("🚀 Disaster Recovery & System Tools"),
            version: String::from("1.0.0"),
            items: vec![
                // System Analysis & Backup
                MenuItem {
                    name: String::from("📊 Analyze System"),
                    description: String::from("Create complete system snapshot for reproduction"),
                    command: String::from("~/analyze-and-reproduce-system.sh"),
                    category: String::from("Backup"),
                    shortcut: Some('a'),
                    dangerous: false,
                },
                MenuItem {
                    name: String::from("💾 Sync to NFS Backup"),
                    description: String::from("Backup local data to NFS storage"),
                    command: String::from("~/sync-to-nfs-backup.sh sync"),
                    category: String::from("Backup"),
                    shortcut: Some('s'),
                    dangerous: false,
                },
                MenuItem {
                    name: String::from("📈 NFS Backup Status"),
                    description: String::from("Check NFS backup sync status"),
                    command: String::from("~/sync-to-nfs-backup.sh status"),
                    category: String::from("Backup"),
                    shortcut: None,
                    dangerous: false,
                },
                
                // Restoration
                MenuItem {
                    name: String::from("🔄 One-Shot Restore"),
                    description: String::from("Complete system restoration from backup"),
                    command: String::from("~/one-shot-restore.sh"),
                    category: String::from("Restore"),
                    shortcut: Some('r'),
                    dangerous: true,
                },
                MenuItem {
                    name: String::from("📥 Pull from NFS"),
                    description: String::from("Restore configs from NFS for new system"),
                    command: String::from("~/sync-from-nfs-restore.sh pull"),
                    category: String::from("Restore"),
                    shortcut: Some('p'),
                    dangerous: false,
                },
                MenuItem {
                    name: String::from("👁️ Check NFS Backup"),
                    description: String::from("View available backups on NFS"),
                    command: String::from("~/sync-from-nfs-restore.sh check"),
                    category: String::from("Restore"),
                    shortcut: Some('c'),
                    dangerous: false,
                },
                
                // Mount Management
                MenuItem {
                    name: String::from("🔗 Check Mounts"),
                    description: String::from("Check and fix NFS mount status"),
                    command: String::from("~/check-and-mount-nfs.sh"),
                    category: String::from("Mount"),
                    shortcut: Some('m'),
                    dangerous: false,
                },
                
                // Chezmoi
                MenuItem {
                    name: String::from("🏠 Chezmoi Status"),
                    description: String::from("Check dotfile management status"),
                    command: String::from("chezmoi status"),
                    category: String::from("Dotfiles"),
                    shortcut: Some('d'),
                    dangerous: false,
                },
                MenuItem {
                    name: String::from("🔄 Chezmoi Update"),
                    description: String::from("Pull and apply latest dotfiles"),
                    command: String::from("chezmoi update"),
                    category: String::from("Dotfiles"),
                    shortcut: None,
                    dangerous: false,
                },
                
                // Automation
                MenuItem {
                    name: String::from("⚙️ Setup NFS Auto-Backup"),
                    description: String::from("Configure automated NFS backup timer"),
                    command: String::from("~/setup-nfs-backup-automation.sh"),
                    category: String::from("Setup"),
                    shortcut: None,
                    dangerous: false,
                },
                MenuItem {
                    name: String::from("⏰ View Timers"),
                    description: String::from("Show systemd timer status"),
                    command: String::from("systemctl --user list-timers"),
                    category: String::from("Setup"),
                    shortcut: Some('t'),
                    dangerous: false,
                },
                
                // System Info
                MenuItem {
                    name: String::from("💽 Disk Usage"),
                    description: String::from("Show disk space usage"),
                    command: String::from("df -h /mnt/projects-share /home"),
                    category: String::from("Info"),
                    shortcut: None,
                    dangerous: false,
                },
                MenuItem {
                    name: String::from("📂 Backup Size"),
                    description: String::from("Show size of local backup data"),
                    command: String::from("du -sh /mnt/projects-share/dtaylor/* | sort -h"),
                    category: String::from("Info"),
                    shortcut: None,
                    dangerous: false,
                },
            ],
        };

        // Try to load from config file, otherwise use defaults
        let config_path = dirs::home_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join(".config/disaster-recovery/menu.json");

        if config_path.exists() {
            let contents = std::fs::read_to_string(&config_path)?;
            Ok(serde_json::from_str(&contents)?)
        } else {
            // Save default config for future customization
            if let Some(parent) = config_path.parent() {
                std::fs::create_dir_all(parent).ok();
            }
            let json = serde_json::to_string_pretty(&default_config)?;
            std::fs::write(&config_path, json).ok();
            Ok(default_config)
        }
    }

    pub fn run_command(&mut self, index: usize) -> Result<()> {
        if index >= self.filtered_items.len() {
            return Ok(());
        }

        let actual_index = self.filtered_items[index];
        let item = &self.items[actual_index];
        
        self.status_message = format!("Running: {}", item.name);
        
        // Clear screen before running command
        execute!(io::stdout(), LeaveAlternateScreen)?;
        disable_raw_mode()?;
        
        println!("\n🚀 Executing: {}\n", item.name);
        println!("Command: {}\n", item.command);
        
        // Run the command
        let output = Command::new("sh")
            .arg("-c")
            .arg(&item.command)
            .output()?;
        
        // Show output
        if !output.stdout.is_empty() {
            println!("{}", String::from_utf8_lossy(&output.stdout));
        }
        if !output.stderr.is_empty() {
            eprintln!("{}", String::from_utf8_lossy(&output.stderr));
        }
        
        // Store output for display in TUI
        self.last_command_output = String::from_utf8_lossy(&output.stdout)
            .lines()
            .map(String::from)
            .collect();
        
        if output.status.success() {
            self.status_message = format!("✓ {} completed successfully", item.name);
        } else {
            self.status_message = format!("✗ {} failed with exit code: {}", 
                item.name, 
                output.status.code().unwrap_or(-1)
            );
        }
        
        println!("\n📋 Press Enter to return to menu...");
        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        
        // Return to TUI
        enable_raw_mode()?;
        execute!(io::stdout(), EnterAlternateScreen)?;
        
        Ok(())
    }

    pub fn update_filter(&mut self) {
        self.filtered_items = self.items
            .iter()
            .enumerate()
            .filter(|(_, item)| {
                item.name.to_lowercase().contains(&self.filter.to_lowercase()) ||
                item.description.to_lowercase().contains(&self.filter.to_lowercase()) ||
                item.category.to_lowercase().contains(&self.filter.to_lowercase())
            })
            .map(|(i, _)| i)
            .collect();
        
        if self.selected >= self.filtered_items.len() && !self.filtered_items.is_empty() {
            self.selected = self.filtered_items.len() - 1;
        }
    }
}

pub fn run_tui() -> Result<()> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create app state
    let mut app = App::new()?;

    // Main loop
    loop {
        terminal.draw(|f| draw_ui(f, &app))?;

        if let Event::Key(key) = event::read()? {
            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Char('h') => {
                    app.show_output = !app.show_output;
                    app.last_command_output = vec![
                        String::from("🎮 Keyboard Shortcuts:"),
                        String::from(""),
                        String::from("  ↑/↓ or j/k  - Navigate menu"),
                        String::from("  Enter       - Run selected tool"),
                        String::from("  /           - Filter items"),
                        String::from("  Esc         - Clear filter"),
                        String::from("  h           - Toggle this help"),
                        String::from("  q           - Quit"),
                        String::from(""),
                        String::from("🔤 Quick Launch:"),
                        String::from("  a - Analyze System"),
                        String::from("  s - Sync to NFS"),
                        String::from("  r - One-Shot Restore"),
                        String::from("  m - Check Mounts"),
                        String::from("  d - Chezmoi Status"),
                    ];
                }
                KeyCode::Up | KeyCode::Char('k') => {
                    if app.selected > 0 {
                        app.selected -= 1;
                    }
                }
                KeyCode::Down | KeyCode::Char('j') => {
                    if app.selected < app.filtered_items.len().saturating_sub(1) {
                        app.selected += 1;
                    }
                }
                KeyCode::Enter => {
                    app.run_command(app.selected)?;
                }
                KeyCode::Char('/') => {
                    app.filter.clear();
                    app.status_message = String::from("Type to filter (Esc to clear)");
                }
                KeyCode::Backspace => {
                    app.filter.pop();
                    app.update_filter();
                }
                KeyCode::Char(c) if !app.filter.is_empty() || key.code == KeyCode::Char('/') => {
                    if c != '/' {
                        app.filter.push(c);
                        app.update_filter();
                    }
                }
                KeyCode::Char(c) => {
                    // Check for shortcuts
                    for (i, actual_i) in app.filtered_items.iter().enumerate() {
                        if let Some(shortcut) = app.items[*actual_i].shortcut {
                            if c == shortcut {
                                app.selected = i;
                                app.run_command(i)?;
                                break;
                            }
                        }
                    }
                }
                _ => {}
            }
            
            if key.code == KeyCode::Esc && !app.filter.is_empty() {
                app.filter.clear();
                app.update_filter();
                app.status_message = String::from("Filter cleared");
            }
        }
    }

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    Ok(())
}

fn draw_ui(f: &mut Frame, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),  // Header
            Constraint::Min(10),     // Main content
            Constraint::Length(3),  // Status bar
        ])
        .split(f.size());

    // Header
    let header = Paragraph::new(Text::from(vec![
        Line::from(vec![
            Span::styled(&app.config.title, Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
            Span::raw(" "),
            Span::styled(format!("v{}", app.config.version), Style::default().fg(Color::DarkGray)),
        ]),
    ]))
    .block(Block::default().borders(Borders::ALL))
    .alignment(Alignment::Center);
    f.render_widget(header, chunks[0]);

    // Main area - split into menu and output
    let (menu_area, output_area) = if app.show_output {
        let split = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
            .split(chunks[1]);
        (split[0], Some(split[1]))
    } else {
        (chunks[1], None)
    };

    // Menu items
    let items: Vec<ListItem> = app.filtered_items
        .iter()
        .enumerate()
        .map(|(i, actual_i)| {
            let item = &app.items[*actual_i];
            let style = if i == app.selected {
                Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD)
            } else if item.dangerous {
                Style::default().fg(Color::Yellow)
            } else {
                Style::default()
            };

            let shortcut = item.shortcut
                .map(|s| format!("[{}] ", s))
                .unwrap_or_else(|| String::from("    "));

            let category_color = match item.category.as_str() {
                "Backup" => Color::Green,
                "Restore" => Color::Yellow,
                "Mount" => Color::Blue,
                "Dotfiles" => Color::Magenta,
                "Setup" => Color::Cyan,
                _ => Color::White,
            };

            ListItem::new(Line::from(vec![
                Span::styled(shortcut, Style::default().fg(Color::DarkGray)),
                Span::raw(&item.name),
                Span::raw(" "),
                Span::styled(format!("[{}]", item.category), Style::default().fg(category_color)),
                Span::raw("\n    "),
                Span::styled(&item.description, Style::default().fg(Color::DarkGray)),
            ]))
            .style(style)
        })
        .collect();

    let menu_title = if app.filter.is_empty() {
        String::from(" Tools ")
    } else {
        format!(" Tools (filtered: {}) ", app.filter)
    };

    let menu = List::new(items)
        .block(Block::default().borders(Borders::ALL).title(menu_title));
    f.render_widget(menu, menu_area);

    // Output panel (if visible)
    if let Some(output_rect) = output_area {
        let output_text = app.last_command_output.join("\n");
        let output = Paragraph::new(output_text)
            .block(Block::default().borders(Borders::ALL).title(" Output "))
            .wrap(Wrap { trim: true });
        f.render_widget(output, output_rect);
    }

    // Status bar
    let status = Paragraph::new(Line::from(vec![
        Span::raw(&app.status_message),
        Span::raw(" | "),
        Span::styled("h:help q:quit /:filter Enter:run", Style::default().fg(Color::DarkGray)),
    ]))
    .block(Block::default().borders(Borders::ALL));
    f.render_widget(status, chunks[2]);
}