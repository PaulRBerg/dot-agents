set shell := ["bash", "-euo", "pipefail", "-c"]

# ---------------------------------------------------------------------------- #
#                                   COMMANDS                                   #
# ---------------------------------------------------------------------------- #

# Show available commands
default:
    @just --list

# ---------------------------------------------------------------------------- #
#                                    CHECKS                                    #
# ---------------------------------------------------------------------------- #

# Check Markdown formatting
@mdformat-check +paths=".":
    uvx mdformat --check {{ paths }}

alias mc := mdformat-check

# Format Markdown files
@mdformat-write +paths=".":
    uvx mdformat {{ paths }}

alias mw := mdformat-write

# ---------------------------------------------------------------------------- #
#                                    SKILLS                                    #
# ---------------------------------------------------------------------------- #

# List skills (active and shelved)
[group("skills")]
@skill-list:
    echo "Active skills:"
    ls -1 skills 2>/dev/null || echo "  (none)"
    echo ""
    echo "Deactivated skills:"
    ls -1 shelf 2>/dev/null || echo "  (none)"

alias sl := skill-list
alias list := skill-list

# Activate a skill (move from shelf to skills)
[group("skills")]
@skill-activate name:
    mv "shelf/{{ name }}" "skills/{{ name }}"
    echo "Activated: {{ name }}"

alias sa := skill-activate

# Deactivate a skill (move from skills to shelf)
[group("skills")]
@skill-deactivate name:
    mv "skills/{{ name }}" "shelf/{{ name }}"
    echo "Deactivated: {{ name }}"

alias sd := skill-deactivate

# Purge all skills and print reinstall commands
[confirm("This will purge all skills. Continue? [y/N]")]
[group("skills")]
[script("bash")]
reset-skills:
    set -euo pipefail
    rm -rf ./skills
    rm -rf ~/.codex/skills
    find ~/.claude/skills -mindepth 1 -maxdepth 1 ! -name '.system' -exec rm -rf {} +
    rm -f .skill-lock.json
    echo ""
    echo "Skills purged. Run these commands to reinstall:"
    echo ""
    echo "  npx skills add PaulRBerg/agent-skills"
    echo "  npx skills add sablier-labs/agent-skills"
    echo "  npx skills add vercel-labs/agent-skills"

alias rs := reset-skills
