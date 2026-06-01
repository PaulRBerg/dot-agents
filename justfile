set shell := ["bash", "-euo", "pipefail", "-c"]

# ---------------------------------------------------------------------------- #
#                                   COMMANDS                                   #
# ---------------------------------------------------------------------------- #

# Show available commands
default:
    @just skill-list

# Abort if the working tree has uncommitted changes
[private]
@_require-clean:
    git diff --quiet && git diff --cached --quiet || { echo 'Error: uncommitted changes in git' >&2; exit 1; }

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

# List skills
[group("skills")]
@skill-list:
    echo -e '{{ BOLD }}{{ GREEN }}● Skills:{{ NORMAL }}'
    ls -1 skills 2>/dev/null | sed 's/^/  {{ CYAN }}▸ /' | sed 's/$/{{ NORMAL }}/' | while read -r line; do echo -e "$line"; done || echo -e '  {{ YELLOW }}(none){{ NORMAL }}'

alias sl := skill-list
alias list := skill-list

# Update installed skills from their sources
[group("skills")]
[script("zsh", "-i")]
skill-update:
    set -euo pipefail
    typeset -a updated
    for dir in skills/*(/N); do
        name=${dir:t}
        source=$(jq -r --arg n "$name" '.skills[$n].source // empty' .skill-lock.json)
        if [[ -z "$source" ]]; then
            echo -e '{{ RED }}Error: no source found for '"$name"' in .skill-lock.json{{ NORMAL }}' >&2
            exit 1
        fi
        npx skills add "$source" --global --agent claude-code --skill "$name" --yes > /dev/null
        updated+=("$name")
        echo -e '{{ GREEN }}✅ Updated: {{ BOLD }}'"$name"'{{ NORMAL }}'
    done
    if [[ ${#updated[@]} -eq 0 ]]; then
        echo -e '{{ YELLOW }}No skills found to update{{ NORMAL }}'
    fi

alias su := skill-update

# Install skills from a repo
[group("skills")]
[script("zsh", "-i")]
install-all repo="PaulRBerg/agent-skills": _require-clean
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

alias ia := install-all

# Purge all skills and print reinstall commands
[confirm("This will purge all skills. Continue? [y/N]")]
[group("skills")]
[script("bash")]
reset-skills: _require-clean
    set -euo pipefail
    npx skills remove --all --global --yes > /dev/null
    rm -f .skill-lock.json
    echo ""
    echo "Skills purged. Run these commands to reinstall:"
    echo ""
    echo "  npx skills add PaulRBerg/agent-skills"
    echo "  npx skills add sablier-labs/agent-skills"
    echo "  npx skills add vercel-labs/agent-skills"

alias rs := reset-skills
