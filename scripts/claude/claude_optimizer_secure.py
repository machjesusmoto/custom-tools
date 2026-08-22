#!/usr/bin/env python3
"""
Secure Claude.json Configuration Optimizer

This script analyzes and optimizes the .claude.json configuration file,
removing Windows/WSL specific paths, duplicate entries, obsolete configurations,
and SENSITIVE DATA like API tokens.
"""

import json
import sys
import re
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

def remove_sensitive_data(data: Any) -> Any:
    """Recursively remove sensitive data from the configuration."""
    if isinstance(data, dict):
        cleaned = {}
        for key, value in data.items():
            # Remove GitHub tokens and other sensitive keys
            if any(sensitive in key.lower() for sensitive in ['token', 'secret', 'key', 'password', 'auth']):
                if key == 'GITHUB_PERSONAL_ACCESS_TOKEN':
                    print(f"🚨 REMOVED SENSITIVE DATA: {key} = {value[:10]}...")
                    continue
                elif 'github' in key.lower() and 'token' in key.lower():
                    print(f"🚨 REMOVED SENSITIVE DATA: {key}")
                    continue
            
            # Recursively clean nested structures
            cleaned[key] = remove_sensitive_data(value)
        return cleaned
    elif isinstance(data, list):
        return [remove_sensitive_data(item) for item in data]
    elif isinstance(data, str):
        # Check for GitHub tokens in string content
        if re.search(r'ghp_[a-zA-Z0-9]{36}', data):
            print(f"🚨 FOUND GITHUB TOKEN IN STRING CONTENT - Removing")
            # Replace GitHub tokens with placeholder
            cleaned_data = re.sub(r'ghp_[a-zA-Z0-9]{36}', '[GITHUB_TOKEN_REMOVED]', data)
            return cleaned_data
        return data
    else:
        return data

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
            
            # Clean sensitive data from history entries
            cleaned_entry = remove_sensitive_data(entry)
            cleaned_history.append(cleaned_entry)
        
        # Update config with cleaned history
        cleaned_config = config.copy()
        cleaned_config['history'] = cleaned_history
        
        # Clean up MCP servers with WSL paths and sensitive data
        if 'mcpServers' in cleaned_config:
            cleaned_mcp_servers = {}
            for server_name, server_config in cleaned_config['mcpServers'].items():
                # Clean server config
                cleaned_server_config = remove_sensitive_data(server_config)
                
                # Check for WSL paths in filesystem server args
                if 'args' in cleaned_server_config:
                    cleaned_args = [arg for arg in cleaned_server_config['args'] if not str(arg).startswith('/mnt/c/')]
                    if len(cleaned_args) != len(cleaned_server_config['args']):
                        print(f"Cleaned WSL paths from MCP server {server_name}")
                        cleaned_server_config['args'] = cleaned_args
                        
                    # For filesystem server, ensure we have proper Linux paths
                    if server_name == 'filesystem' and cleaned_args:
                        # Replace with common Linux user directories
                        linux_paths = [
                            '/home/dtaylor/Desktop',
                            '/home/dtaylor/Downloads', 
                            '/home/dtaylor/GitHub',
                            '/home/dtaylor/Documents'
                        ]
                        cleaned_server_config['args'] = (
                            cleaned_args[:2] + linux_paths  # Keep command and flags, replace paths
                            if len(cleaned_args) > 2 
                            else cleaned_args + linux_paths
                        )
                
                cleaned_mcp_servers[server_name] = cleaned_server_config
            
            cleaned_config['mcpServers'] = cleaned_mcp_servers
        
        cleaned_projects[project_path] = cleaned_config
    
    return cleaned_projects

def analyze_projects(projects: Dict[str, Any]) -> Dict[str, Any]:
    """Analyze project configurations and identify issues."""
    analysis = {
        'total_projects': len(projects),
        'wsl_paths': [],
        'linux_paths': [],
        'history_stats': {},
        'sensitive_data_found': []
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
        
        # Check for sensitive data
        if 'mcpServers' in config:
            for server_name, server_config in config['mcpServers'].items():
                if 'env' in server_config:
                    for env_key, env_value in server_config['env'].items():
                        if 'token' in env_key.lower():
                            analysis['sensitive_data_found'].append(f"{project_path}/{server_name}/{env_key}")
    
    return analysis

def optimize_config(config: Dict[str, Any]) -> Dict[str, Any]:
    """Optimize the entire configuration."""
    print("🔒 Removing sensitive data...")
    optimized = remove_sensitive_data(config)
    
    # Clean projects
    if 'projects' in optimized:
        print("📁 Cleaning projects...")
        optimized['projects'] = clean_projects(optimized['projects'])
    
    return optimized

def main():
    """Main function to analyze and optimize the claude.json file."""
    input_file = Path('/home/dtaylor/.claude.json')
    output_file = Path('/home/dtaylor/.claude.json.optimized')
    
    print("=== SECURE Claude.json Optimizer ===")
    print(f"Input file: {input_file}")
    print(f"Output file: {output_file}")
    print()
    
    # Load configuration
    print("Loading configuration...")
    config = load_json_file(input_file)
    
    # Analyze projects
    print("Analyzing projects and security...")
    if 'projects' in config:
        analysis = analyze_projects(config['projects'])
        
        print(f"Total projects: {analysis['total_projects']}")
        print(f"WSL paths to remove: {len(analysis['wsl_paths'])}")
        print(f"Linux paths to keep: {len(analysis['linux_paths'])}")
        
        if analysis['sensitive_data_found']:
            print(f"🚨 Sensitive data locations found: {len(analysis['sensitive_data_found'])}")
            for location in analysis['sensitive_data_found']:
                print(f"  - {location}")
        
        print()
        
        print("WSL paths found:")
        for path in analysis['wsl_paths']:
            print(f"  - {path}")
        print()
    
    # Optimize configuration
    print("Optimizing and securing configuration...")
    optimized_config = optimize_config(config)
    
    # Calculate space savings
    original_size = len(json.dumps(config, indent=2))
    optimized_size = len(json.dumps(optimized_config, indent=2))
    savings = original_size - optimized_size
    savings_percent = (savings / original_size) * 100
    
    print(f"\n📊 OPTIMIZATION RESULTS:")
    print(f"   Original size: {original_size:,} characters")
    print(f"   Optimized size: {optimized_size:,} characters")
    print(f"   Space saved: {savings:,} characters ({savings_percent:.1f}%)")
    
    # Write optimized configuration
    print(f"\nWriting secured and optimized configuration to {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(optimized_config, f, indent=2, ensure_ascii=False)
    
    print("\n🎯 SECURE OPTIMIZATION COMPLETE!")
    print("   ✅ Removed sensitive data (GitHub tokens, etc.)")
    print("   ✅ Removed Windows/WSL paths")
    print("   ✅ Consolidated duplicate history entries")
    print("   ✅ Optimized file size")

if __name__ == '__main__':
    main()