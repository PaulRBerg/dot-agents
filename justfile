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

# Recreate Claude Code skill links via the skills CLI
[group("skills")]
[script("bash")]
sync-claude:
    set -euo pipefail
    lock=".skill-lock.json"
    claude_skills_dir="$HOME/.claude/skills"

    mkdir -p "$claude_skills_dir"
    find "$claude_skills_dir" -maxdepth 1 -type l ! -exec test -e {} \; -delete
    [[ -f "$lock" ]] || { echo "No $lock found"; exit 0; }

    jq -r '
      .skills
      | to_entries
      | map({
          name: .key,
          source: (if .value.sourceType == "github" then .value.source else .value.sourceUrl end),
          ref: (.value.ref // "")
        })
      | group_by([.source, .ref])
      | .[]
      | [.[0].source, .[0].ref, (map(.name) | join(" "))] | @tsv
    ' "$lock" | while IFS=$'\t' read -r source ref skills; do
        needed=()
        for skill in $skills; do
            [[ -f "skills/$skill/SKILL.md" ]] || continue

            link="$claude_skills_dir/$skill"
            [[ -L "$link" && "$(readlink "$link")" == "../../.agents/skills/$skill" ]] && continue

            needed+=("$skill")
        done
        ((${#needed[@]})) || continue

        install_source="$source"
        [[ -n "$ref" ]] && install_source="$install_source#$ref"

        extra=()
        [[ "$source" == openclaw/* ]] && extra+=(--dangerously-accept-openclaw-risks)

        npx skills add "$install_source" --global --agent claude-code codex --skill "${needed[@]}" --yes "${extra[@]}"
    done

alias ssc := sync-claude

# Update all installed skills from their sources
[group("skills")]
@skill-update: _require-clean
    npx skills update --global --yes
    just sync-claude

alias su := skill-update

# Install skills from a repo
[group("skills")]
[script("bash")]
install-all repo="PaulRBerg/agent-skills": _require-clean
    set -euo pipefail
    gum spin \
        --title 'Installing skills from {{ repo }}...' \
        --show-error \
        -- npx skills add '{{ repo }}' \
        --global \
        --agent claude-code codex \
        --skill '*' \
        --yes
    printf '{{ GREEN }}%s{{ NORMAL }}\n' '✅ Installed all skills from {{ repo }}'

alias ia := install-all

# Purge all skills and print reinstall commands
[confirm("This will purge all skills. Continue? [y/N]")]
[group("skills")]
[script("bash")]
reset-skills: _require-clean
    set -euo pipefail
    npx skills remove --all --global --yes > /dev/null
    just sync-claude
    rm -f .skill-lock.json
    echo ""
    echo "Skills purged. Run these commands to reinstall:"
    echo ""
    echo "  npx skills add PaulRBerg/agent-skills"
    echo "  npx skills add sablier-labs/agent-skills"
    echo "  npx skills add vercel-labs/agent-skills"

alias rs := reset-skills
