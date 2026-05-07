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

# List skills (active and shelved)
[group("skills")]
@skill-list:
    echo -e '{{ BOLD }}{{ GREEN }}● Active skills:{{ NORMAL }}'
    ls -1 skills 2>/dev/null | sed 's/^/  {{ CYAN }}▸ /' | sed 's/$/{{ NORMAL }}/' | while read -r line; do echo -e "$line"; done || echo -e '  {{ YELLOW }}(none){{ NORMAL }}'
    echo ""
    echo -e '{{ BOLD }}{{ YELLOW }}○ Shelved skills:{{ NORMAL }}'
    jq -r '.[]' shelf.json 2>/dev/null | sed 's/^/  {{ BLUE }}▹ /' | sed 's/$/{{ NORMAL }}/' | while read -r line; do echo -e "$line"; done || echo -e '  {{ YELLOW }}(none){{ NORMAL }}'

alias sl := skill-list
alias list := skill-list

# Activate skills (re-install from source)
[group("skills")]
[script("zsh", "-i")]
skill-activate +names:
    set -euo pipefail
    for name in {{ names }}; do
        source=$(jq -r --arg n "$name" '.skills[$n].source // empty' .skill-lock.json)
        if [ -z "$source" ]; then
            echo -e '{{ RED }}Error: no source found for '"$name"' in .skill-lock.json{{ NORMAL }}' >&2
            exit 1
        fi
        jq --arg n "$name" '. - [$n]' shelf.json > shelf.json.tmp && mv shelf.json.tmp shelf.json
        npx skills add "$source" --global --agent claude-code --skill "$name" --yes > /dev/null
        echo -e '{{ GREEN }}✅ Activated: {{ BOLD }}'"$name"'{{ NORMAL }}'
    done

alias sa := skill-activate

# Deactivate skills (add to shelf and remove directory)
[group("skills")]
[script("bash")]
skill-deactivate +names:
    set -euo pipefail
    for name in {{ names }}; do
        jq --arg n "$name" '. + [$n] | unique | sort' shelf.json > shelf.json.tmp && mv shelf.json.tmp shelf.json
        rm -rf "skills/$name"
        echo -e '{{ YELLOW }}📦 Shelved: {{ BOLD }}'"$name"'{{ NORMAL }}'
    done

alias sd := skill-deactivate

# Install skills from a repo, removing any that are shelved
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
    removed=()
    for name in $(jq -r '.[]' shelf.json 2>/dev/null); do
        if [ -d "skills/$name" ]; then
            rm -rf "skills/$name"
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
reset-skills: _require-clean
    set -euo pipefail
    rm -rf ./skills
    rm -rf ~/.codex/skills
    find ~/.claude/skills -mindepth 1 -maxdepth 1 ! -name '.system' -exec rm -rf {} +
    rm -f .skill-lock.json
    echo '[]' > shelf.json
    echo ""
    echo "Skills purged. Run these commands to reinstall:"
    echo ""
    echo "  npx skills add PaulRBerg/agent-skills"
    echo "  npx skills add sablier-labs/agent-skills"
    echo "  npx skills add vercel-labs/agent-skills"

alias rs := reset-skills
