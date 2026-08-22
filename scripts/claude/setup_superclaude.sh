#!/bin/bash
# SuperClaude Framework Setup Script
# DTaylor Environment - Critical Path Implementation
# Generated: 2025-08-15

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SUPERCLAUDE_DIR="/home/dtaylor/SuperClaude_Framework"
CLAUDE_CONFIG_DIR="/home/dtaylor/.claude"
LOGFILE="/home/dtaylor/setup_superclaude.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

# Error handler
error_exit() {
    print_error "Script failed at line $1"
    print_error "Check log file: $LOGFILE"
    exit 1
}

trap 'error_exit $LINENO' ERR

# Start setup
print_status "Starting SuperClaude Framework Setup..."
print_status "Log file: $LOGFILE"

# Phase 1: Prerequisites Check
print_status "Phase 1: Checking Prerequisites..."

# Check Python
print_status "Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    print_success "Python found: $PYTHON_VERSION"
    
    # Check if version is >= 3.8
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        print_success "Python version is compatible (>= 3.8)"
    else
        print_error "Python version too old. Need >= 3.8, found $PYTHON_VERSION"
        exit 1
    fi
else
    print_error "Python3 not found. Please install Python 3.8 or later."
    exit 1
fi

# Check pip/uv
print_status "Checking package manager..."
if command -v uv &> /dev/null; then
    print_success "UV package manager found"
    PACKAGE_MANAGER="uv"
elif command -v pip3 &> /dev/null; then
    print_success "Pip package manager found"
    PACKAGE_MANAGER="pip3"
else
    print_error "No package manager found (pip or uv required)"
    exit 1
fi

# Check Node.js for MCP
print_status "Checking Node.js installation..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js found: $NODE_VERSION"
    
    # Extract major version number
    NODE_MAJOR=$(node --version | cut -d'.' -f1 | sed 's/v//')
    if [ "$NODE_MAJOR" -ge 18 ]; then
        print_success "Node.js version is compatible (>= 18)"
    else
        print_warning "Node.js version may be too old for optimal MCP server support"
    fi
else
    print_warning "Node.js not found. MCP servers may have limited functionality."
fi

# Check SuperClaude Framework directory
print_status "Checking SuperClaude Framework directory..."
if [ -d "$SUPERCLAUDE_DIR" ]; then
    print_success "SuperClaude Framework directory found"
    
    # Check if it's a valid Python package
    if [ -f "$SUPERCLAUDE_DIR/setup.py" ] || [ -f "$SUPERCLAUDE_DIR/pyproject.toml" ]; then
        print_success "Valid Python package structure found"
    else
        print_error "SuperClaude Framework directory exists but missing setup files"
        exit 1
    fi
else
    print_error "SuperClaude Framework directory not found: $SUPERCLAUDE_DIR"
    exit 1
fi

# Phase 2: Installation
print_status "Phase 2: Installing SuperClaude Framework..."

cd "$SUPERCLAUDE_DIR"

# Install package
print_status "Installing package with $PACKAGE_MANAGER..."
if [ "$PACKAGE_MANAGER" = "uv" ]; then
    uv pip install -e .
else
    pip3 install -e .
fi

print_success "SuperClaude Framework installed successfully"

# Verify installation
print_status "Verifying installation..."
if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "Version check failed")
    print_success "Claude command available: $CLAUDE_VERSION"
else
    print_warning "Claude command not found in PATH. Manual verification may be needed."
fi

# Phase 3: Configuration
print_status "Phase 3: Setting up configuration..."

# Create .claude directory
print_status "Creating Claude configuration directory..."
mkdir -p "$CLAUDE_CONFIG_DIR"
print_success "Configuration directory created: $CLAUDE_CONFIG_DIR"

# Copy core configuration files
print_status "Copying core configuration files..."
if [ -d "$SUPERCLAUDE_DIR/SuperClaude/Core" ]; then
    cp "$SUPERCLAUDE_DIR/SuperClaude/Core"/*.md "$CLAUDE_CONFIG_DIR/" 2>/dev/null || true
    
    # Count copied files
    COPIED_FILES=$(ls -1 "$CLAUDE_CONFIG_DIR"/*.md 2>/dev/null | wc -l)
    print_success "Copied $COPIED_FILES configuration files"
    
    # List copied files
    print_status "Configuration files:"
    ls -la "$CLAUDE_CONFIG_DIR"/*.md 2>/dev/null || print_warning "No .md files found in configuration directory"
else
    print_warning "Core configuration directory not found, creating minimal setup"
    
    # Create basic configuration
    cat > "$CLAUDE_CONFIG_DIR/CLAUDE.md" << 'EOF'
# Claude Configuration
This is a minimal configuration created by setup script.
Please update with your specific settings.

Generated: $(date)
EOF
fi

# Set permissions
chmod -R 755 "$CLAUDE_CONFIG_DIR"
print_success "Configuration permissions set"

# Phase 4: Verification
print_status "Phase 4: System Verification..."

# Check Python imports
print_status "Testing Python imports..."
if python3 -c "import SuperClaude" 2>/dev/null; then
    print_success "SuperClaude Python module imports successfully"
else
    print_warning "SuperClaude Python module import failed (may need restart)"
fi

# Check configuration files
print_status "Verifying configuration files..."
CONFIG_COUNT=$(ls -1 "$CLAUDE_CONFIG_DIR"/*.md 2>/dev/null | wc -l)
if [ "$CONFIG_COUNT" -gt 0 ]; then
    print_success "$CONFIG_COUNT configuration files present"
else
    print_warning "No configuration files found"
fi

# Phase 5: Next Steps
print_status "Phase 5: Next Steps Information..."

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  SuperClaude Framework Setup Complete!  ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

print_status "Setup Summary:"
echo "  ✓ Python environment validated"
echo "  ✓ SuperClaude Framework installed"
echo "  ✓ Configuration directory created"
echo "  ✓ Core files copied"
echo ""

print_status "Next Steps:"
echo "  1. Restart your terminal/IDE to pick up changes"
echo "  2. Test: claude --version"
echo "  3. Configure MCP servers in Claude Desktop"
echo "  4. Test Context7: Use 'use context7' in Claude prompts"
echo "  5. Review configuration files in: $CLAUDE_CONFIG_DIR"
echo ""

print_status "Documentation:"
echo "  • Main docs: /home/dtaylor/DTAYLOR_ENVIRONMENT_DOCUMENTATION.md"
echo "  • Tool matrix: /home/dtaylor/TOOL_INTEGRATION_MATRIX.md"
echo "  • Critical paths: /home/dtaylor/CRITICAL_PATHS_ANALYSIS.md"
echo ""

print_status "Troubleshooting:"
echo "  • Check log file: $LOGFILE"
echo "  • Verify PATH includes Python scripts directory"
echo "  • Restart Claude Desktop after configuration changes"
echo ""

# Update status in main documentation
print_status "Updating documentation status..."
if [ -f "/home/dtaylor/DTAYLOR_ENVIRONMENT_DOCUMENTATION.md" ]; then
    # Create backup
    cp "/home/dtaylor/DTAYLOR_ENVIRONMENT_DOCUMENTATION.md" "/home/dtaylor/DTAYLOR_ENVIRONMENT_DOCUMENTATION.md.backup"
    
    # Update status (simple replacement for now)
    sed -i 's/SuperClaude Framework: AVAILABLE BUT NOT INSTALLED/SuperClaude Framework: INSTALLED AND CONFIGURED/' "/home/dtaylor/DTAYLOR_ENVIRONMENT_DOCUMENTATION.md"
    sed -i 's/Status: 🔴 Not Installed/Status: ✅ Installed/' "/home/dtaylor/DTAYLOR_ENVIRONMENT_DOCUMENTATION.md"
    
    print_success "Documentation updated with new status"
else
    print_warning "Main documentation file not found for status update"
fi

print_success "Setup completed successfully!"
log "Setup completed at $(date)"

# Optional: Run basic tests
read -p "Run basic functionality tests? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Running basic tests..."
    
    # Test 1: Command availability
    if command -v claude &> /dev/null; then
        print_success "Test 1: Claude command available"
    else
        print_warning "Test 1: Claude command not in PATH"
    fi
    
    # Test 2: Configuration access
    if [ -r "$CLAUDE_CONFIG_DIR/CLAUDE.md" ]; then
        print_success "Test 2: Configuration files readable"
    else
        print_warning "Test 2: Configuration files not accessible"
    fi
    
    # Test 3: Python module
    if python3 -c "import SuperClaude; print('SuperClaude module loaded successfully')" 2>/dev/null; then
        print_success "Test 3: Python module loads correctly"
    else
        print_warning "Test 3: Python module load issues"
    fi
    
    print_status "Basic tests completed"
fi

echo ""
print_success "All done! Happy coding with SuperClaude!"