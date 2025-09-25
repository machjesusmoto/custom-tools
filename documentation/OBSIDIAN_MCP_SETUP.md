# Obsidian MCP Integration Setup Guide
*Last Updated: August 15, 2025*

This guide will help you connect Claude Code with your Obsidian vault using the Model Context Protocol (MCP) server.

## ✅ Current Status

- **Obsidian Vault**: Located at `~/Obsidian/`
- **MCP Server**: Installed at `~/ai-tools/obsidian-mcp-server/`
- **Node.js**: v24.5.0 (installed)
- **Build Status**: Complete

## 📋 Setup Steps

### Step 1: Install Obsidian REST API Plugin

1. Open Obsidian
2. Go to Settings → Community plugins
3. Browse and search for "Local REST API"
4. Install the plugin by coddingtonbear
5. Enable the plugin
6. In the plugin settings:
   - Set a secure API key (generate a random string)
   - Note the port (default: 27123)
   - Enable the API server

### Step 2: Configure MCP Server Environment

Create a configuration file for the MCP server:

```bash
# Create environment configuration
cat > ~/ai-tools/obsidian-mcp-server/.env << 'EOF'
OBSIDIAN_API_KEY=YOUR_API_KEY_HERE
OBSIDIAN_BASE_URL=http://127.0.0.1:27123
OBSIDIAN_VERIFY_SSL=false
LOG_LEVEL=info
EOF
```

Replace `YOUR_API_KEY_HERE` with the API key you set in the Obsidian plugin.

### Step 3: Update Claude Settings

For Claude Desktop, add this to your MCP settings configuration:

```json
{
  "mcpServers": {
    "obsidian": {
      "command": "node",
      "args": ["/home/dtaylor/ai-tools/obsidian-mcp-server/dist/index.js"],
      "env": {
        "OBSIDIAN_API_KEY": "YOUR_API_KEY_HERE",
        "OBSIDIAN_BASE_URL": "http://127.0.0.1:27123",
        "OBSIDIAN_VERIFY_SSL": "false",
        "LOG_LEVEL": "info"
      }
    }
  }
}
```

### Step 4: Test the Integration

1. Ensure Obsidian is running with the REST API plugin enabled
2. Test the REST API directly:
   ```bash
   curl -H "Authorization: Bearer YOUR_API_KEY_HERE" \
        http://127.0.0.1:27123/vault/
   ```

3. Run the MCP server manually to test:
   ```bash
   cd ~/ai-tools/obsidian-mcp-server
   OBSIDIAN_API_KEY=YOUR_API_KEY_HERE \
   OBSIDIAN_BASE_URL=http://127.0.0.1:27123 \
   node dist/index.js
   ```

## 🛠️ Available MCP Tools

Once configured, Claude will have access to these Obsidian tools:

| Tool | Description | Usage |
|------|-------------|-------|
| `obsidian_read_note` | Read note content and metadata | Read any note by path |
| `obsidian_update_note` | Modify notes (append/prepend/overwrite) | Update existing notes or create new ones |
| `obsidian_search_replace` | Search and replace within notes | Perform regex or string replacements |
| `obsidian_global_search` | Search across entire vault | Find content across all notes |
| `obsidian_list_notes` | List notes in directories | Browse vault structure |
| `obsidian_manage_frontmatter` | Manage YAML frontmatter | Get/set/delete metadata |
| `obsidian_manage_tags` | Add/remove/list tags | Organize notes with tags |
| `obsidian_delete_note` | Delete notes | Remove notes from vault |

## 📁 File Locations

- **Obsidian Vault**: `~/Obsidian/`
- **MCP Server**: `~/ai-tools/obsidian-mcp-server/`
- **Server Binary**: `~/ai-tools/obsidian-mcp-server/dist/index.js`
- **Configuration**: `~/ai-tools/obsidian-mcp-server/.env`

## 🔧 Troubleshooting

### Issue: Connection Refused
- Ensure Obsidian is running
- Check that the REST API plugin is enabled
- Verify the port number (default: 27123)

### Issue: Authentication Failed
- Verify the API key matches in both Obsidian and MCP configuration
- Check that the Authorization header is being sent

### Issue: MCP Server Not Starting
- Check Node.js installation: `node --version`
- Rebuild if necessary: `cd ~/ai-tools/obsidian-mcp-server && npm run build`
- Check logs in the console output

## 🚀 Usage Examples

### Save Claude Conversation
```javascript
// Claude can now save conversations directly to your vault
await obsidian_update_note({
  path: "AI Conversations/claude-2025-08-15.md",
  content: conversationContent,
  mode: "overwrite"
});
```

### Search Your Knowledge Base
```javascript
// Claude can search your entire vault
const results = await obsidian_global_search({
  query: "MCP integration",
  options: { regex: false }
});
```

### Manage Note Metadata
```javascript
// Claude can update frontmatter
await obsidian_manage_frontmatter({
  path: "Projects/MCP Setup.md",
  action: "set",
  key: "tags",
  value: ["claude", "mcp", "integration"]
});
```

## 📝 Next Steps

1. **Configure the REST API plugin** in Obsidian with a secure API key
2. **Update the .env file** with your API key
3. **Test the connection** using curl
4. **Add to Claude settings** if using Claude Desktop
5. **Start using** Claude to interact with your Obsidian vault!

## 🔗 Resources

- [Obsidian Local REST API Plugin](https://github.com/coddingtonbear/obsidian-local-rest-api)
- [MCP Server Repository](https://github.com/cyanheads/obsidian-mcp-server)
- [Model Context Protocol Docs](https://modelcontextprotocol.io/)

---
*Note: Keep your API key secure and never commit it to version control.*