# dot-agents

Central repository for cross-agent AI skills (Claude Code, Codex CLI, etc.).

## Structure

- `skills/` - Reusable skill definitions
- `commands/` - Custom slash commands
- `hooks/` - Event-driven automation

## Development

```bash
just              # List available commands
just mc           # Check markdown formatting
just mw           # Format markdown files
```

## Guidelines

- Keep skills portable across AI agents
- Use clear, descriptive skill names
- Document skill triggers and usage in skill files
