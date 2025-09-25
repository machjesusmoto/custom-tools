#!/bin/bash
# AI Tools Reorganization Script
# Date: August 15, 2025
# Purpose: Consolidate AI tools into ~/ai-tools with symlink compatibility

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting AI Tools Reorganization...${NC}"

# Step 1: Create ai-tools directory
echo -e "${YELLOW}Creating ai-tools directory...${NC}"
mkdir -p ~/ai-tools

# Step 2: Move AIShell
if [ -d ~/AIShell ]; then
    echo -e "${YELLOW}Moving AIShell...${NC}"
    mv ~/AIShell ~/ai-tools/
    ln -sf ~/ai-tools/AIShell ~/AIShell
    echo -e "${GREEN}✓ AIShell moved and symlinked${NC}"
else
    echo -e "${RED}AIShell not found, skipping...${NC}"
fi

# Step 3: Move serena
if [ -d ~/serena ]; then
    echo -e "${YELLOW}Moving serena...${NC}"
    mv ~/serena ~/ai-tools/
    ln -sf ~/ai-tools/serena ~/serena
    echo -e "${GREEN}✓ serena moved and symlinked${NC}"
else
    echo -e "${RED}serena not found, skipping...${NC}"
fi

# Step 4: Move Fabric
if [ -d ~/Fabric ]; then
    echo -e "${YELLOW}Moving Fabric source...${NC}"
    mv ~/Fabric ~/ai-tools/
    ln -sf ~/ai-tools/Fabric ~/Fabric
    echo -e "${GREEN}✓ Fabric source moved and symlinked${NC}"
fi

# Handle fabric binary separately
if [ -f ~/fabric ]; then
    echo -e "${YELLOW}Moving fabric binary...${NC}"
    mv ~/fabric ~/ai-tools/fabric-binary
    ln -sf ~/ai-tools/fabric-binary ~/fabric
    echo -e "${GREEN}✓ fabric binary moved and symlinked${NC}"
fi

# Step 5: Move semanticworkbench
if [ -d ~/semanticworkbench ]; then
    echo -e "${YELLOW}Moving semanticworkbench...${NC}"
    mv ~/semanticworkbench ~/ai-tools/
    ln -sf ~/ai-tools/semanticworkbench ~/semanticworkbench
    echo -e "${GREEN}✓ semanticworkbench moved and symlinked${NC}"
else
    echo -e "${RED}semanticworkbench not found, skipping...${NC}"
fi

# Step 6: Move context7-setup
if [ -d ~/context7-setup ]; then
    echo -e "${YELLOW}Moving context7-setup...${NC}"
    mv ~/context7-setup ~/ai-tools/
    # No symlink needed for context7-setup as it's just setup files
    echo -e "${GREEN}✓ context7-setup moved${NC}"
else
    echo -e "${RED}context7-setup not found, skipping...${NC}"
fi

# Step 7: Move SuperClaude_Framework
if [ -d ~/SuperClaude_Framework ]; then
    echo -e "${YELLOW}Moving SuperClaude_Framework...${NC}"
    mv ~/SuperClaude_Framework ~/ai-tools/
    ln -sf ~/ai-tools/SuperClaude_Framework ~/SuperClaude_Framework
    echo -e "${GREEN}✓ SuperClaude_Framework moved and symlinked${NC}"
fi

# Step 8: Create README for ai-tools
cat > ~/ai-tools/README.md << 'EOF'
# AI Tools Directory

This directory contains all AI-related tools and frameworks for the dtaylor environment.

## Tools Inventory

| Tool | Description | Status | Binary/Source |
|------|-------------|--------|---------------|
| AIShell | Microsoft's AI CLI | ✅ Active | Source |
| serena | Semantic coding agent (MCP) | ⚠️ Needs config | Source |
| Fabric | AI patterns framework | ✅ Active (needs API key) | Source |
| fabric-binary | Fabric executable v1.4.272 | ✅ Active | Binary |
| semanticworkbench | Multi-agent platform | ✅ Active | Source |
| context7-setup | MCP server setup files | ✅ Configured | Setup files |
| SuperClaude_Framework | Claude Code framework | ✅ Active | Source |

## Symlinks

For backward compatibility, symlinks are maintained in the home directory:
- `~/AIShell` → `~/ai-tools/AIShell`
- `~/serena` → `~/ai-tools/serena`
- `~/Fabric` → `~/ai-tools/Fabric`
- `~/fabric` → `~/ai-tools/fabric-binary`
- `~/semanticworkbench` → `~/ai-tools/semanticworkbench`
- `~/SuperClaude_Framework` → `~/ai-tools/SuperClaude_Framework`

## Usage

All tools can be accessed using their original paths thanks to symlinks.
The actual files are organized here for cleaner structure.

## MCP Integration

Serena and Context7 are configured as MCP servers in `~/.claude/settings.json`

---
*Last updated: August 15, 2025*
EOF

echo -e "${GREEN}✓ README created${NC}"

# Step 9: Update MCP configuration if needed
echo -e "${YELLOW}Checking MCP configuration...${NC}"
if [ -f ~/.claude/settings.json ]; then
    # Backup current settings
    cp ~/.claude/settings.json ~/.claude/settings.json.backup_$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✓ MCP settings backed up${NC}"
    
    # Note: Manual update may be needed for serena path
    echo -e "${YELLOW}Note: You may need to update serena path in ~/.claude/settings.json${NC}"
    echo -e "${YELLOW}New path should be: ~/ai-tools/serena${NC}"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Reorganization Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "- All AI tools moved to ~/ai-tools/"
echo "- Symlinks created for backward compatibility"
echo "- README documentation created"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test tool functionality"
echo "2. Update MCP configuration if needed"
echo "3. Remove this script after verification"