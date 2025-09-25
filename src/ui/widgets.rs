use crossterm::event::{KeyCode, KeyEvent};
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, Paragraph, Wrap},
};
use zeroize::Zeroize;

use crate::core::security::{SecurePassword, PasswordStrength, validate_password_strength};

/// Password input widget with secure handling
pub struct PasswordInput {
    input: String,
    cursor_position: usize,
    show_strength: bool,
    strength: Option<PasswordStrength>,
    confirm_mode: bool,
    confirm_input: String,
    confirm_cursor: usize,
    active_field: PasswordField,
}

#[derive(Debug, Clone, PartialEq)]
enum PasswordField {
    Password,
    Confirm,
}

impl PasswordInput {
    pub fn new(show_strength: bool, confirm_mode: bool) -> Self {
        Self {
            input: String::new(),
            cursor_position: 0,
            show_strength,
            strength: None,
            confirm_mode,
            confirm_input: String::new(),
            confirm_cursor: 0,
            active_field: PasswordField::Password,
        }
    }

    pub fn handle_key(&mut self, key: KeyEvent) -> Option<SecurePassword> {
        match key.code {
            KeyCode::Char(c) => {
                match self.active_field {
                    PasswordField::Password => {
                        self.input.insert(self.cursor_position, c);
                        self.cursor_position += 1;
                        if self.show_strength {
                            self.update_strength();
                        }
                    }
                    PasswordField::Confirm => {
                        self.confirm_input.insert(self.confirm_cursor, c);
                        self.confirm_cursor += 1;
                    }
                }
            }
            KeyCode::Backspace => {
                match self.active_field {
                    PasswordField::Password => {
                        if self.cursor_position > 0 {
                            self.cursor_position -= 1;
                            self.input.remove(self.cursor_position);
                            if self.show_strength {
                                self.update_strength();
                            }
                        }
                    }
                    PasswordField::Confirm => {
                        if self.confirm_cursor > 0 {
                            self.confirm_cursor -= 1;
                            self.confirm_input.remove(self.confirm_cursor);
                        }
                    }
                }
            }
            KeyCode::Left => {
                match self.active_field {
                    PasswordField::Password => {
                        self.cursor_position = self.cursor_position.saturating_sub(1);
                    }
                    PasswordField::Confirm => {
                        self.confirm_cursor = self.confirm_cursor.saturating_sub(1);
                    }
                }
            }
            KeyCode::Right => {
                match self.active_field {
                    PasswordField::Password => {
                        self.cursor_position = (self.cursor_position + 1).min(self.input.len());
                    }
                    PasswordField::Confirm => {
                        self.confirm_cursor = (self.confirm_cursor + 1).min(self.confirm_input.len());
                    }
                }
            }
            KeyCode::Tab => {
                if self.confirm_mode {
                    self.active_field = match self.active_field {
                        PasswordField::Password => PasswordField::Confirm,
                        PasswordField::Confirm => PasswordField::Password,
                    };
                }
            }
            KeyCode::Enter => {
                if self.confirm_mode {
                    if self.input == self.confirm_input && !self.input.is_empty() {
                        let password = SecurePassword::new(self.input.clone());
                        self.clear();
                        return Some(password);
                    }
                } else if !self.input.is_empty() {
                    let password = SecurePassword::new(self.input.clone());
                    self.clear();
                    return Some(password);
                }
            }
            _ => {}
        }
        None
    }

    pub fn render(&self, frame: &mut ratatui::Frame, area: Rect) {
        // Clear the background
        frame.render_widget(Clear, area);

        let block = Block::default()
            .borders(Borders::ALL)
            .title("Enter Password")
            .title_alignment(Alignment::Center)
            .style(Style::default().bg(Color::Black));

        let inner_area = block.inner(area);
        frame.render_widget(block, area);

        let mut constraints = vec![
            Constraint::Length(3), // Password field
        ];

        if self.confirm_mode {
            constraints.push(Constraint::Length(3)); // Confirm field
        }

        if self.show_strength && self.strength.is_some() {
            constraints.push(Constraint::Length(4)); // Strength indicator
        }

        constraints.push(Constraint::Min(1)); // Instructions

        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints(constraints)
            .split(inner_area);

        let mut chunk_index = 0;

        // Password field
        let password_display = "*".repeat(self.input.len());
        let password_style = if self.active_field == PasswordField::Password {
            Style::default().fg(Color::Yellow)
        } else {
            Style::default().fg(Color::Gray)
        };

        let password_block = Block::default()
            .borders(Borders::ALL)
            .title("Password")
            .style(password_style);

        let password_paragraph = Paragraph::new(password_display)
            .block(password_block);

        frame.render_widget(password_paragraph, chunks[chunk_index]);
        chunk_index += 1;

        // Confirm field (if in confirm mode)
        if self.confirm_mode {
            let confirm_display = "*".repeat(self.confirm_input.len());
            let confirm_style = if self.active_field == PasswordField::Confirm {
                Style::default().fg(Color::Yellow)
            } else {
                Style::default().fg(Color::Gray)
            };

            let confirm_block = Block::default()
                .borders(Borders::ALL)
                .title("Confirm Password")
                .style(confirm_style);

            let confirm_paragraph = Paragraph::new(confirm_display)
                .block(confirm_block);

            frame.render_widget(confirm_paragraph, chunks[chunk_index]);
            chunk_index += 1;
        }

        // Strength indicator (if enabled and available)
        if self.show_strength {
            if let Some(ref strength) = self.strength {
            let strength_color = match strength.score {
                80.. => Color::Green,
                60..80 => Color::Yellow,
                40..60 => Color::Rgb(255, 165, 0), // Orange
                _ => Color::Red,
            };

            let strength_text = format!("Strength: {}% - {}", strength.score, 
                strength.feedback.first().unwrap_or(&"".to_string()));

            let strength_block = Block::default()
                .borders(Borders::ALL)
                .title("Password Strength")
                .style(Style::default().fg(strength_color));

            let strength_paragraph = Paragraph::new(strength_text)
                .block(strength_block)
                .wrap(Wrap { trim: true });

                frame.render_widget(strength_paragraph, chunks[chunk_index]);
                chunk_index += 1;
            }
        }

        // Instructions
        let mut instructions = vec![
            Line::from("Enter your password and press Enter to continue"),
        ];

        if self.confirm_mode {
            instructions.push(Line::from("Use Tab to switch between fields"));
            if self.input != self.confirm_input {
                instructions.push(Line::from(vec![
                    Span::styled("Passwords do not match!", Style::default().fg(Color::Red))
                ]));
            }
        }

        instructions.push(Line::from("Press Esc to cancel"));

        let instructions_paragraph = Paragraph::new(instructions)
            .alignment(Alignment::Center)
            .wrap(Wrap { trim: true });

        frame.render_widget(instructions_paragraph, chunks[chunk_index]);
    }

    fn update_strength(&mut self) {
        if !self.input.is_empty() {
            let password = SecurePassword::new(self.input.clone());
            self.strength = Some(validate_password_strength(&password));
        } else {
            self.strength = None;
        }
    }

    fn clear(&mut self) {
        self.input.zeroize();
        self.input.clear();
        self.confirm_input.zeroize();
        self.confirm_input.clear();
        self.cursor_position = 0;
        self.confirm_cursor = 0;
        self.strength = None;
        self.active_field = PasswordField::Password;
    }
}

impl Drop for PasswordInput {
    fn drop(&mut self) {
        self.clear();
    }
}

/// Menu widget for selection screens
pub struct Menu {
    items: Vec<MenuItem>,
    selected_index: usize,
}

pub struct MenuItem {
    pub key: char,
    pub label: String,
    pub description: String,
    pub enabled: bool,
}

impl MenuItem {
    pub fn new(key: char, label: String, description: String) -> Self {
        Self {
            key,
            label,
            description,
            enabled: true,
        }
    }

    pub fn disabled(mut self) -> Self {
        self.enabled = false;
        self
    }
}

impl Menu {
    pub fn new(items: Vec<MenuItem>) -> Self {
        Self {
            items,
            selected_index: 0,
        }
    }

    pub fn handle_key(&mut self, key: KeyEvent) -> Option<char> {
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                self.move_selection_up();
            }
            KeyCode::Down | KeyCode::Char('j') => {
                self.move_selection_down();
            }
            KeyCode::Enter => {
                if let Some(item) = self.items.get(self.selected_index) {
                    if item.enabled {
                        return Some(item.key);
                    }
                }
            }
            KeyCode::Char(c) => {
                if let Some(item) = self.items.iter().find(|item| item.key == c) {
                    if item.enabled {
                        return Some(c);
                    }
                }
            }
            _ => {}
        }
        None
    }

    pub fn render(&self, frame: &mut ratatui::Frame, area: Rect, title: &str) {
        let block = Block::default()
            .borders(Borders::ALL)
            .title(title)
            .title_alignment(Alignment::Center);

        let inner_area = block.inner(area);
        frame.render_widget(block, area);

        let menu_lines: Vec<Line> = self.items
            .iter()
            .enumerate()
            .map(|(i, item)| {
                let is_selected = i == self.selected_index;
                let style = if !item.enabled {
                    Style::default().fg(Color::DarkGray)
                } else if is_selected {
                    Style::default().bg(Color::Blue).fg(Color::White)
                } else {
                    Style::default()
                };

                let prefix = if is_selected { "▶ " } else { "  " };
                
                Line::from(vec![
                    Span::raw(prefix),
                    Span::styled(format!("{}. ", item.key), Style::default().fg(Color::Yellow)),
                    Span::styled(&item.label, style.add_modifier(Modifier::BOLD)),
                    Span::raw(" - "),
                    Span::styled(&item.description, style),
                ])
            })
            .collect();

        let menu_paragraph = Paragraph::new(menu_lines)
            .alignment(Alignment::Left)
            .wrap(Wrap { trim: true });

        frame.render_widget(menu_paragraph, inner_area);
    }

    fn move_selection_up(&mut self) {
        if self.selected_index > 0 {
            self.selected_index -= 1;
        } else {
            self.selected_index = self.items.len().saturating_sub(1);
        }
    }

    fn move_selection_down(&mut self) {
        if self.selected_index < self.items.len().saturating_sub(1) {
            self.selected_index += 1;
        } else {
            self.selected_index = 0;
        }
    }
}

/// Loading spinner widget
pub struct LoadingSpinner {
    frames: Vec<&'static str>,
    current_frame: usize,
}

impl LoadingSpinner {
    pub fn new() -> Self {
        Self {
            frames: vec!["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
            current_frame: 0,
        }
    }

    pub fn tick(&mut self) {
        self.current_frame = (self.current_frame + 1) % self.frames.len();
    }

    pub fn render(&self, frame: &mut ratatui::Frame, area: Rect, message: &str) {
        let spinner_text = format!("{} {}", self.frames[self.current_frame], message);
        
        let spinner = Paragraph::new(spinner_text)
            .alignment(Alignment::Center)
            .style(Style::default().fg(Color::Blue).add_modifier(Modifier::BOLD));

        frame.render_widget(spinner, area);
    }
}

impl Default for LoadingSpinner {
    fn default() -> Self {
        Self::new()
    }
}