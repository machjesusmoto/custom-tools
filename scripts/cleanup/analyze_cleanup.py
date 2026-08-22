#!/usr/bin/env python3
"""
Analyze cleanup results and generate a detailed summary.
"""

import json
from pathlib import Path

def analyze_cleanup():
    """Analyze the cleanup results and generate a detailed report."""
    
    original_file = Path('/home/dtaylor/.claude.json')
    optimized_file = Path('/home/dtaylor/.claude.json.optimized')
    
    # Load both files
    with open(original_file, 'r') as f:
        original = json.load(f)
    
    with open(optimized_file, 'r') as f:
        optimized = json.load(f)
    
    print("=== CLAUDE.JSON OPTIMIZATION SUMMARY ===\n")
    
    # File sizes
    original_size = original_file.stat().st_size
    optimized_size = optimized_file.stat().st_size
    size_reduction = original_size - optimized_size
    size_reduction_percent = (size_reduction / original_size) * 100
    
    print(f"📊 FILE SIZE REDUCTION:")
    print(f"   Original: {original_size:,} bytes ({original_size/1024:.1f} KB)")
    print(f"   Optimized: {optimized_size:,} bytes ({optimized_size/1024:.1f} KB)")
    print(f"   Saved: {size_reduction:,} bytes ({size_reduction_percent:.1f}%)")
    print()
    
    # Project analysis
    original_projects = original.get('projects', {})
    optimized_projects = optimized.get('projects', {})
    
    print(f"🗂️  PROJECT CLEANUP:")
    print(f"   Original projects: {len(original_projects)}")
    print(f"   Optimized projects: {len(optimized_projects)}")
    print(f"   Projects removed: {len(original_projects) - len(optimized_projects)}")
    print()
    
    # WSL paths removed
    wsl_paths_removed = []
    for path in original_projects:
        if path.startswith('/mnt/c/') and path not in optimized_projects:
            wsl_paths_removed.append(path)
    
    print(f"🪟 WSL PATHS REMOVED ({len(wsl_paths_removed)}):")
    for path in wsl_paths_removed:
        history_count = len(original_projects[path].get('history', []))
        print(f"   ❌ {path} ({history_count} history entries)")
    print()
    
    # Remaining Linux paths
    linux_paths = [path for path in optimized_projects if not path.startswith('/mnt/c/')]
    print(f"🐧 LINUX PATHS PRESERVED ({len(linux_paths)}):")
    for path in linux_paths:
        history_count = len(optimized_projects[path].get('history', []))
        print(f"   ✅ {path} ({history_count} history entries)")
    print()
    
    # History analysis
    original_total_history = sum(len(project.get('history', [])) for project in original_projects.values())
    optimized_total_history = sum(len(project.get('history', [])) for project in optimized_projects.values())
    history_reduction = original_total_history - optimized_total_history
    
    print(f"📚 HISTORY CLEANUP:")
    print(f"   Original total history entries: {original_total_history}")
    print(f"   Optimized total history entries: {optimized_total_history}")
    print(f"   History entries removed: {history_reduction}")
    print()
    
    # MCP Server analysis
    mcp_changes = []
    for path, project in optimized_projects.items():
        for server_name, server_config in project.get('mcpServers', {}).items():
            if server_name == 'filesystem' and 'args' in server_config:
                # Check if filesystem server was cleaned
                args = server_config['args']
                linux_paths = [arg for arg in args if str(arg).startswith('/home/dtaylor/')]
                if linux_paths:
                    mcp_changes.append(f"   ✅ {server_name} server: Updated to use Linux paths")
    
    if mcp_changes:
        print(f"🔧 MCP SERVER UPDATES:")
        for change in mcp_changes:
            print(change)
        print()
    
    # Configuration preservation
    preserved_configs = [
        'numStartups', 'installMethod', 'autoUpdates', 'theme', 'tipsHistory',
        'firstStartTime', 'userID', 'oauthAccount', 'hasCompletedOnboarding'
    ]
    
    print(f"⚙️  CONFIGURATIONS PRESERVED:")
    for config in preserved_configs:
        if config in optimized:
            if config == 'tipsHistory':
                tip_count = len(optimized[config])
                print(f"   ✅ {config} ({tip_count} tips)")
            elif config == 'firstStartTime':
                print(f"   ✅ {config}: {optimized[config]}")
            else:
                print(f"   ✅ {config}")
    print()
    
    print("🎯 OPTIMIZATION COMPLETE!")
    print("   The optimized configuration maintains all important settings")
    print("   while removing Windows/WSL cruft and reducing file size.")
    print(f"   Backup the original file before replacing it with the optimized version.")

if __name__ == '__main__':
    analyze_cleanup()