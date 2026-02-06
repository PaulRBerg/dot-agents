# Skills CLI Issue Workflow

This reference document describes the workflow for creating issues in the `vercel-labs/skills` repository. The workflow automatically selects the appropriate issue template based on the issue description and generates structured issue content.

## Validate Authentication

Check if GitHub CLI is authenticated:

```bash
gh auth status 2>&1 | rg -q "Logged in"
```

If not authenticated, error with: "Run `gh auth login` first"

## Determine Issue Type

From the issue description, infer which template fits best:

| Keywords                                                 | Template              | Title Prefix   |
| -------------------------------------------------------- | --------------------- | -------------- |
| bug, broken, error, crash, fails, doesn't work           | `bug-report.yml`      | `[Bug]: `      |
| feature, request, add, support, wish, would be nice      | `feature-request.yml` | `[Feature]: `  |
| agent, new agent, support agent, coding agent, IDE       | `agent-request.yml`   | `[Agent]: `    |

**If ambiguous or no strong match**: Use AskUserQuestion with these options:

- Bug Report - something's broken in the CLI
- Feature Request - new idea or enhancement
- Agent Request - request support for a new coding agent

## Generate Issue Body

Based on the template type, generate a body with these sections:

### Bug Report Template

```markdown
### Description

{describe the bug from description}

### Steps to Reproduce

1. {step 1}
2. {step 2}
3. ...

### Expected Behavior

{expected behavior}

### Actual Behavior

{what actually happened}

### Version

{skills --version or npx skills --version - from context or "unknown"}

### Node.js Version

{node --version - from context}

### Operating System

{macOS/Windows/Linux}

### Logs / Error Output

```shell
{any relevant error output, or "N/A"}
```
```

### Feature Request Template

```markdown
### Problem

{what problem does this feature solve?}

### Proposed Solution

{how should it work?}

### Alternatives Considered

{any workarounds or other approaches - or "None" if not mentioned}

### Additional Context

{any other relevant context, screenshots, or examples - or "None"}
```

### Agent Request Template

```markdown
### Agent Name

{name of the coding agent, e.g., Cursor, Claude Code, Windsurf}

### Skills Documentation URL

{link to the agent's skills/rules documentation}

### Project Skills Directory

{where skills are stored at the project level, e.g., .cursor/skills}

### Global Skills Directory

{where skills are stored at the user/global level, e.g., ~/.cursor/skills}

### Detection Path

{path to check if the agent is installed, e.g., ~/.cursor}
```

## Generate Title

Create a concise title (5-10 words) with the appropriate prefix:

- Bug: `[Bug]: {what's broken}`
- Feature: `[Feature]: {what you want}`
- Agent: `[Agent]: {agent name} support`

## Create the Issue

Use GitHub CLI to create the issue:

```bash
gh issue create \
  --repo "vercel-labs/skills" \
  --title "$title" \
  --body "$(cat <<'EOF'
$body
EOF
)"
```

**Note**: Template labels (`bug`, `enhancement`) are applied automatically by GitHub when matching the template format.

Display: "Created: $URL"

On failure: show error and suggest fix

## Environment Detection

Gather environment information for bug reports:

- **Skills CLI version**: `npx skills --version 2>/dev/null || echo "unknown"`
- **Node.js version**: `node --version 2>/dev/null || echo "unknown"`
- **Platform**: macOS version, `uname -mprs` (Linux), or PowerShell for Windows

## Examples

```bash
# Bug report
"npx skills add crashes when the skill repo has no .agents directory"

# Feature request
"Add support for installing skills from a lockfile"

# Agent request
"Add support for Zed editor as a coding agent"
```
