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
