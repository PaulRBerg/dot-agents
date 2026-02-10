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
    echo -e '{{ BOLD }}{{ GREEN }}● Active skills:{{ NORMAL }}'
    ls -1 skills 2>/dev/null | sed 's/^/  {{ CYAN }}▸ /' | sed 's/$/{{ NORMAL }}/' | while read -r line; do echo -e "$line"; done || echo -e '  {{ YELLOW }}(none){{ NORMAL }}'
    echo ""
    echo -e '{{ BOLD }}{{ YELLOW }}○ Shelved skills:{{ NORMAL }}'
    ls -1 shelf 2>/dev/null | sed 's/^/  {{ BLUE }}▹ /' | sed 's/$/{{ NORMAL }}/' | while read -r line; do echo -e "$line"; done || echo -e '  {{ YELLOW }}(none){{ NORMAL }}'

alias sl := skill-list
alias list := skill-list

# Activate skills (move from shelf to skills)
[group("skills")]
[script("bash")]
skill-activate +names:
    for name in {{ names }}; do
        mv "shelf/$name" "skills/$name"
        echo -e '{{ GREEN }}✅ Activated: {{ BOLD }}'"$name"'{{ NORMAL }}'
    done

alias sa := skill-activate

# Deactivate skills (move from skills to shelf)
[group("skills")]
[script("bash")]
skill-deactivate +names:
    for name in {{ names }}; do
        mv "skills/$name" "shelf/$name"
        echo -e '{{ YELLOW }}📦 Shelved: {{ BOLD }}'"$name"'{{ NORMAL }}'
    done

alias sd := skill-deactivate

# Install PaulRBerg skills, removing any that are shelved
[group("skills")]
[script("bash")]
install-prb:
    set -euo pipefail
    npx skills add PaulRBerg/agent-skills --yes --all
    removed=()
    for entry in shelf/*; do
        name=$(basename "$entry")
        if [ -d "skills/$name" ]; then
            npx skills remove "$name" -y
            removed+=("$name")
        fi
    done
    if [ ${#removed[@]} -gt 0 ]; then
        echo -e '{{ YELLOW }}📦 Removed shelved skills: {{ BOLD }}'"${removed[*]}"'{{ NORMAL }}'
    fi

alias ip := install-prb

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
