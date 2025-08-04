use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, Gauge, List, ListItem, Paragraph, Wrap},
};

use crate::core::types::{BackupItem, RestoreItem, SecurityLevel};
use crate::ui::terminal::{format_bytes, truncate_text};

/// Header component showing application title and current state
pub fn render_header(
    frame: &mut ratatui::Frame,
    area: Rect,
    title: &str,
    subtitle: Option<&str>,
) {
    let header_block = Block::default()
        .borders(Borders::ALL)
        .style(Style::default().fg(Color::Cyan));

    let header_text = if let Some(subtitle) = subtitle {
        vec![
            Line::from(vec![
                Span::styled(title, Style::default().add_modifier(Modifier::BOLD)),
            ]),
            Line::from(vec![
                Span::styled(subtitle, Style::default().fg(Color::Gray)),
            ]),
        ]
    } else {
        vec![Line::from(vec![
            Span::styled(title, Style::default().add_modifier(Modifier::BOLD)),
        ])]
    };

    let header = Paragraph::new(header_text)
        .block(header_block)
        .alignment(Alignment::Center)
        .wrap(Wrap { trim: true });

    frame.render_widget(header, area);
}

/// Footer component showing keyboard shortcuts and status
pub fn render_footer(
    frame: &mut ratatui::Frame,
    area: Rect,
    shortcuts: &[(&str, &str)],
    status: Option<&str>,
) {
    let footer_block = Block::default()
        .borders(Borders::ALL)
        .style(Style::default().fg(Color::Gray));

    let mut footer_spans = Vec::new();
    
    for (i, (key, desc)) in shortcuts.iter().enumerate() {
        if i > 0 {
            footer_spans.push(Span::raw(" | "));
        }
        footer_spans.push(Span::styled(*key, Style::default().fg(Color::Yellow)));
        footer_spans.push(Span::raw(": "));
        footer_spans.push(Span::raw(*desc));
    }

    if let Some(status) = status {
        if !footer_spans.is_empty() {
            footer_spans.push(Span::raw(" | "));
        }
        footer_spans.push(Span::styled(status, Style::default().fg(Color::Green)));
    }

    let footer = Paragraph::new(Line::from(footer_spans))
        .block(footer_block)
        .alignment(Alignment::Center)
        .wrap(Wrap { trim: true });

    frame.render_widget(footer, area);
}

/// Backup item list component with selection support
pub fn render_backup_item_list(
    frame: &mut ratatui::Frame,
    area: Rect,
    items: &[BackupItem],
    selected_index: usize,
    scroll_offset: usize,
) {
    let visible_items: Vec<ListItem> = items
        .iter()
        .skip(scroll_offset)
        .take(area.height.saturating_sub(2) as usize) // Account for borders
        .enumerate()
        .map(|(i, item)| {
            let actual_index = scroll_offset + i;
            let is_selected = actual_index == selected_index;
            
            let checkbox = if item.selected { "☑" } else { "☐" };
            let status_icon = if !item.exists {
                "❌"
            } else {
                match item.security_level {
                    SecurityLevel::High => "🔒",
                    SecurityLevel::Medium => "⚠️",
                    SecurityLevel::Low => " ",
                }
            };
            
            let size_text = item.size
                .map(|s| format_bytes(s))
                .unwrap_or_else(|| "N/A".to_string());
            
            let item_text = format!(
                "{} {} {} ({}) - {}",
                checkbox,
                status_icon,
                truncate_text(&item.name, 30),
                size_text,
                item.category
            );
            
            let style = if is_selected {
                Style::default().bg(Color::Blue).fg(Color::White)
            } else if !item.exists {
                Style::default().fg(Color::Red)
            } else {
                match item.security_level {
                    SecurityLevel::High => Style::default().fg(Color::Red),
                    SecurityLevel::Medium => Style::default().fg(Color::Yellow),
                    SecurityLevel::Low => Style::default(),
                }
            };
            
            ListItem::new(item_text).style(style)
        })
        .collect();

    let list = List::new(visible_items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("Select Items to Backup")
                .title_alignment(Alignment::Center),
        )
        .highlight_style(Style::default().add_modifier(Modifier::BOLD));

    frame.render_widget(list, area);
}

/// Restore item list component with conflict indicators
pub fn render_restore_item_list(
    frame: &mut ratatui::Frame,
    area: Rect,
    items: &[RestoreItem],
    selected_index: usize,
    scroll_offset: usize,
) {
    let visible_items: Vec<ListItem> = items
        .iter()
        .skip(scroll_offset)
        .take(area.height.saturating_sub(2) as usize)
        .enumerate()
        .map(|(i, item)| {
            let actual_index = scroll_offset + i;
            let is_selected = actual_index == selected_index;
            
            let checkbox = if item.selected { "☑" } else { "☐" };
            let conflict_icon = if item.conflicts { "⚠️" } else { " " };
            
            let item_text = format!(
                "{} {} {} ({})",
                checkbox,
                conflict_icon,
                truncate_text(&item.name, 40),
                format_bytes(item.size)
            );
            
            let style = if is_selected {
                Style::default().bg(Color::Blue).fg(Color::White)
            } else if item.conflicts {
                Style::default().fg(Color::Yellow)
            } else {
                Style::default()
            };
            
            ListItem::new(item_text).style(style)
        })
        .collect();

    let list = List::new(visible_items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("Select Items to Restore")
                .title_alignment(Alignment::Center),
        )
        .highlight_style(Style::default().add_modifier(Modifier::BOLD));

    frame.render_widget(list, area);
}

/// Progress bar component for backup/restore operations
pub fn render_progress_bar(
    frame: &mut ratatui::Frame,
    area: Rect,
    title: &str,
    percentage: f64,
    current_item: &str,
    items_completed: usize,
    total_items: usize,
) {
    let progress_block = Block::default()
        .borders(Borders::ALL)
        .title(title)
        .title_alignment(Alignment::Center);

    let progress_area = progress_block.inner(area);
    frame.render_widget(progress_block, area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(3),
            Constraint::Length(1),
            Constraint::Min(0),
        ])
        .split(progress_area);

    // Progress percentage
    let percentage_text = Paragraph::new(format!("{:.1}%", percentage))
        .alignment(Alignment::Center)
        .style(Style::default().add_modifier(Modifier::BOLD));
    frame.render_widget(percentage_text, chunks[0]);

    // Progress bar
    let gauge = Gauge::default()
        .block(Block::default().borders(Borders::ALL))
        .gauge_style(Style::default().fg(Color::Green))
        .percent(percentage as u16)
        .label(format!("{}/{} items", items_completed, total_items));
    frame.render_widget(gauge, chunks[1]);

    // Current item
    let current_item_text = Paragraph::new(format!("Processing: {}", truncate_text(current_item, 50)))
        .alignment(Alignment::Center)
        .style(Style::default().fg(Color::Blue));
    frame.render_widget(current_item_text, chunks[2]);
}

/// Security warning component for sensitive operations
pub fn render_security_warning(
    frame: &mut ratatui::Frame,
    area: Rect,
    warning_text: &str,
) {
    let warning_block = Block::default()
        .borders(Borders::ALL)
        .title("⚠️  Security Warning")
        .title_alignment(Alignment::Center)
        .style(Style::default().fg(Color::Red));

    let warning = Paragraph::new(warning_text)
        .block(warning_block)
        .alignment(Alignment::Center)
        .wrap(Wrap { trim: true })
        .style(Style::default().fg(Color::Yellow));

    frame.render_widget(warning, area);
}

/// Modal dialog component for confirmations
pub fn render_modal(
    frame: &mut ratatui::Frame,
    area: Rect,
    title: &str,
    content: &str,
    buttons: &[&str],
    selected_button: usize,
) {
    // Clear the background
    frame.render_widget(Clear, area);
    
    let modal_block = Block::default()
        .borders(Borders::ALL)
        .title(title)
        .title_alignment(Alignment::Center)
        .style(Style::default().bg(Color::Black).fg(Color::White));

    let modal_area = modal_block.inner(area);
    frame.render_widget(modal_block, area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Min(1),
            Constraint::Length(3),
        ])
        .split(modal_area);

    // Content
    let content_paragraph = Paragraph::new(content)
        .alignment(Alignment::Center)
        .wrap(Wrap { trim: true });
    frame.render_widget(content_paragraph, chunks[0]);

    // Buttons
    let button_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints(
            buttons
                .iter()
                .map(|_| Constraint::Percentage(100 / buttons.len() as u16))
                .collect::<Vec<_>>(),
        )
        .split(chunks[1]);

    for (i, &button_text) in buttons.iter().enumerate() {
        let button_style = if i == selected_button {
            Style::default().bg(Color::Blue).fg(Color::White)
        } else {
            Style::default().fg(Color::Gray)
        };

        let button = Paragraph::new(button_text)
            .alignment(Alignment::Center)
            .block(Block::default().borders(Borders::ALL))
            .style(button_style);

        frame.render_widget(button, button_chunks[i]);
    }
}

/// Summary panel showing backup/restore statistics
pub fn render_summary_panel(
    frame: &mut ratatui::Frame,
    area: Rect,
    title: &str,
    stats: &[(&str, String)],
) {
    let summary_block = Block::default()
        .borders(Borders::ALL)
        .title(title)
        .title_alignment(Alignment::Center);

    let summary_lines: Vec<Line> = stats
        .iter()
        .map(|(label, value)| {
            Line::from(vec![
                Span::styled(format!("{}: ", label), Style::default().add_modifier(Modifier::BOLD)),
                Span::raw(value),
            ])
        })
        .collect();

    let summary = Paragraph::new(summary_lines)
        .block(summary_block)
        .wrap(Wrap { trim: true });

    frame.render_widget(summary, area);
}