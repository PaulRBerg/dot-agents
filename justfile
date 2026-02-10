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

# Install skills from a repo, removing any that are shelved
[group("skills")]
[script("bash")]
install-all repo="PaulRBerg/agent-skills":
    set -euo pipefail
    # TODO: replace "> /dev/null" with "--quiet" when available
    # https://github.com/vercel-labs/skills/issues/331
    npx skills add {{ repo }} \
        --global \
        --agent claude-code \
        --skill '*' \
        --yes \
        > /dev/null
    echo -e '{{ GREEN }}✅ Installed all skills from {{ repo }}{{ NORMAL }}'
    removed=()
    for entry in shelf/*; do
        name=$(basename "$entry")
        if [ -d "skills/$name" ]; then
            npx skills remove "$name" -y > /dev/null
            removed+=("$name")
        fi
    done
    if [ ${#removed[@]} -gt 0 ]; then
        echo -e '{{ YELLOW }}📦 Removed shelved skills: {{ BOLD }}'"${removed[*]}"'{{ NORMAL }}'
    fi

alias ia := install-all

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
