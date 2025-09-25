# Fabric AI Framework - Setup & Usage Guide
*Version: 1.4.272*
*Status: Configured (Needs API Key)*
*Last Updated: August 15, 2025*

## Current Status

✅ **Installed Components:**
- Fabric binary: `~/fabric` (v1.4.272)
- Symlink created: `~/.local/bin/fabric`
- Patterns installed: 227 patterns in `~/.config/fabric/patterns/`
- Configuration: `~/.config/fabric/.env`

⚠️ **Pending Configuration:**
- API Key needed (OpenAI, Anthropic, or other supported provider)

## Quick Setup Instructions

### Option 1: Use OpenAI (Recommended)
```bash
# Add your OpenAI API key to the configuration
echo "OPENAI_API_KEY=your-api-key-here" >> ~/.config/fabric/.env
echo "DEFAULT_VENDOR=openai" >> ~/.config/fabric/.env
echo "DEFAULT_MODEL=gpt-4" >> ~/.config/fabric/.env
```

### Option 2: Use Anthropic Claude
```bash
# Add your Anthropic API key
echo "ANTHROPIC_API_KEY=your-api-key-here" >> ~/.config/fabric/.env
echo "DEFAULT_VENDOR=anthropic" >> ~/.config/fabric/.env
echo "DEFAULT_MODEL=claude-3-sonnet-20240229" >> ~/.config/fabric/.env
```

### Option 3: Use Local Models (Ollama)
```bash
# Install Ollama first
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model
ollama pull llama2

# Configure Fabric
echo "DEFAULT_VENDOR=ollama" >> ~/.config/fabric/.env
echo "DEFAULT_MODEL=llama2" >> ~/.config/fabric/.env
```

## Available Patterns (227 Total)

### Analysis Patterns
- `analyze_claims` - Analyze claims for validity
- `analyze_debate` - Analyze debate arguments
- `analyze_logs` - Analyze system logs
- `analyze_malware` - Analyze malware behavior
- `analyze_paper` - Analyze research papers

### Summarization Patterns
- `summarize` - General summarization
- `summarize_git_changes` - Summarize git commits
- `summarize_meeting` - Summarize meeting notes
- `summarize_paper` - Summarize academic papers
- `summarize_video` - Summarize video content

### Code Patterns
- `explain_code` - Explain code functionality
- `improve_code` - Suggest code improvements
- `create_nmap_command` - Generate nmap commands
- `write_micro_essay` - Write concise essays

### Security Patterns
- `analyze_threat_report` - Analyze security threats
- `create_threat_scenarios` - Generate threat models
- `analyze_incident` - Incident response analysis

## Usage Examples

### Basic Usage
```bash
# Pipe content to a pattern
echo "Your text here" | fabric -p summarize

# Use a file as input
fabric -p analyze_paper < research.pdf

# Stream output
cat article.txt | fabric -p summarize -s

# Use with specific model
fabric -p explain_code -m gpt-4
```

### Advanced Usage
```bash
# Combine with other tools
curl https://example.com | fabric -p extract_article_wisdom

# Git commit analysis
git log --oneline -10 | fabric -p summarize_git_changes

# Code review
cat script.py | fabric -p improve_code

# Meeting notes
fabric -p summarize_meeting < meeting_notes.txt
```

### Pattern Variables
```bash
# Some patterns accept variables
fabric -p agility_story -v role=developer -v points=5
```

## Pattern Categories

| Category | Count | Examples |
|----------|-------|----------|
| Analysis | 45+ | analyze_claims, analyze_debate, analyze_logs |
| Summarization | 20+ | summarize, summarize_meeting, summarize_paper |
| Creation | 30+ | create_keynote, create_quiz, create_summary |
| Extraction | 25+ | extract_wisdom, extract_ideas, extract_sponsors |
| Improvement | 15+ | improve_code, improve_prompt, improve_writing |
| Security | 10+ | analyze_threat_report, create_threat_scenarios |

## Troubleshooting

### Issue: "could not find vendor"
**Solution:** Ensure vendor name is lowercase in `.env`:
- ✅ `DEFAULT_VENDOR=openai`
- ❌ `DEFAULT_VENDOR=OpenAI`

### Issue: "Please run fabric --setup"
**Solution:** Already resolved - patterns are installed manually

### Issue: No API key
**Solution:** Add one of the supported API keys to `~/.config/fabric/.env`

## Integration with Claude Code

While in Claude Code, you can use Fabric patterns to enhance your workflow:

```bash
# Analyze your code
cat myfile.py | fabric -p explain_code

# Summarize documentation
fabric -p summarize < README.md

# Generate test scenarios
echo "Login system with OAuth" | fabric -p create_test_scenarios
```

## File Locations

- **Binary:** `~/fabric`
- **Symlink:** `~/.local/bin/fabric`
- **Config:** `~/.config/fabric/.env`
- **Patterns:** `~/.config/fabric/patterns/`
- **Contexts:** `~/.config/fabric/contexts/`
- **Sessions:** `~/.config/fabric/sessions/`

## Next Steps

1. **Add an API key** to `~/.config/fabric/.env`
2. **Test with:** `echo "test" | fabric -p summarize`
3. **Explore patterns:** `ls ~/.config/fabric/patterns/`
4. **Read pattern docs:** `cat ~/.config/fabric/patterns/[pattern]/system.md`

## Resources

- **GitHub:** https://github.com/danielmiessler/fabric
- **Patterns:** All 227 patterns are in `~/.config/fabric/patterns/`
- **Documentation:** Each pattern has a `system.md` file explaining its purpose

---
*Note: Fabric is ready to use once you add an API key. The framework and patterns are fully installed.*