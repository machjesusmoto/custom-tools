#!/usr/bin/env python3
"""
Claude.json Configuration Optimizer

This script analyzes and optimizes the .claude.json configuration file,
removing Windows/WSL specific paths, duplicate entries, and obsolete configurations.
"""

import json
import sys
from pathlib import Path
from typing import Dict, Any, List, Set
from collections import defaultdict

def load_json_file(file_path: Path) -> Dict[str, Any]:
    """Load and parse the JSON configuration file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error loading {file_path}: {e}")
        sys.exit(1)

def analyze_projects(projects: Dict[str, Any]) -> Dict[str, Any]:
    """Analyze project configurations and identify issues."""
    analysis = {
        'total_projects': len(projects),
        'wsl_paths': [],
        'linux_paths': [],
        'history_stats': {},
        'duplicate_entries': []
    }
    
    for project_path, config in projects.items():
        # Check for WSL paths
        if project_path.startswith('/mnt/c/'):
            analysis['wsl_paths'].append(project_path)
        else:
            analysis['linux_paths'].append(project_path)
        
        # Analyze history
        history = config.get('history', [])
        analysis['history_stats'][project_path] = {
            'count': len(history),
            'has_empty_pasted_contents': sum(1 for entry in history if not entry.get('pastedContents', {}))
        }
    
    return analysis

def clean_projects(projects: Dict[str, Any]) -> Dict[str, Any]:
    """Clean project configurations by removing WSL paths and consolidating."""
    cleaned_projects = {}
    
    for project_path, config in projects.items():
        # Skip Windows/WSL paths
        if project_path.startswith('/mnt/c/'):
            print(f"Removing WSL path: {project_path}")
            continue
        
        # Clean history entries
        history = config.get('history', [])
        cleaned_history = []
        seen_displays = set()
        
        for entry in history:
            display = entry.get('display', '')
            
            # Skip empty or very short entries
            if not display or len(display.strip()) < 3:
                continue
            
            # Skip duplicate displays
            if display in seen_displays:
                continue
                
            seen_displays.add(display)
            cleaned_history.append(entry)
        
        # Update config with cleaned history
        cleaned_config = config.copy()
        cleaned_config['history'] = cleaned_history
        
        # Clean up MCP servers with WSL paths
        if 'mcpServers' in cleaned_config:
            for server_name, server_config in list(cleaned_config['mcpServers'].items()):
                # Check for WSL paths in filesystem server args
                if 'args' in server_config:
                    cleaned_args = [arg for arg in server_config['args'] if not str(arg).startswith('/mnt/c/')]
                    if len(cleaned_args) != len(server_config['args']):
                        print(f"Cleaned WSL paths from MCP server {server_name}")
                        server_config['args'] = cleaned_args
        
        cleaned_projects[project_path] = cleaned_config
    
    return cleaned_projects

def check_obsolete_configs(config: Dict[str, Any]) -> List[str]:
    """Check for potentially obsolete configurations."""
    obsolete_items = []
    
    # Check for very old timestamps (before 2025)
    first_start = config.get('firstStartTime', '')
    if first_start and '2024' in first_start:
        obsolete_items.append(f"Old firstStartTime: {first_start}")
    
    # Check for excessive tip history
    tips_history = config.get('tipsHistory', {})
    if len(tips_history) > 20:
        obsolete_items.append(f"Large tipsHistory with {len(tips_history)} entries")
    
    return obsolete_items

def optimize_config(config: Dict[str, Any]) -> Dict[str, Any]:
    """Optimize the entire configuration."""
    optimized = config.copy()
    
    # Clean projects
    if 'projects' in optimized:
        optimized['projects'] = clean_projects(optimized['projects'])
    
    return optimized

def main():
    """Main function to analyze and optimize the claude.json file."""
    input_file = Path('/home/dtaylor/.claude.json')
    output_file = Path('/home/dtaylor/.claude.json.optimized')
    
    print("=== Claude.json Optimizer ===")
    print(f"Input file: {input_file}")
    print(f"Output file: {output_file}")
    print()
    
    # Load configuration
    print("Loading configuration...")
    config = load_json_file(input_file)
    
    # Analyze projects
    print("Analyzing projects...")
    if 'projects' in config:
        analysis = analyze_projects(config['projects'])
        
        print(f"Total projects: {analysis['total_projects']}")
        print(f"WSL paths to remove: {len(analysis['wsl_paths'])}")
        print(f"Linux paths to keep: {len(analysis['linux_paths'])}")
        print()
        
        print("WSL paths found:")
        for path in analysis['wsl_paths']:
            print(f"  - {path}")
        print()
        
        print("History statistics:")
        for path, stats in analysis['history_stats'].items():
            if stats['count'] > 0:
                print(f"  {path}: {stats['count']} entries")
    
    # Check for obsolete configurations
    print("\nChecking for obsolete configurations...")
    obsolete = check_obsolete_configs(config)
    for item in obsolete:
        print(f"  - {item}")
    
    # Optimize configuration
    print("\nOptimizing configuration...")
    optimized_config = optimize_config(config)
    
    # Calculate space savings
    original_size = len(json.dumps(config, indent=2))
    optimized_size = len(json.dumps(optimized_config, indent=2))
    savings = original_size - optimized_size
    savings_percent = (savings / original_size) * 100
    
    print(f"Original size: {original_size:,} characters")
    print(f"Optimized size: {optimized_size:,} characters")
    print(f"Space saved: {savings:,} characters ({savings_percent:.1f}%)")
    
    # Write optimized configuration
    print(f"\nWriting optimized configuration to {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(optimized_config, f, indent=2, ensure_ascii=False)
    
    print("Optimization complete!")

if __name__ == '__main__':
    main()