set shell := ["bash", "-euo", "pipefail", "-c"]

prettier := "bunx --no-install prettier"
prettier_cache := ".cache/prettier/.prettier-cache"
prettier_globs := "\"**/*.{md,json,jsonc,yaml,yml}\""

# ---------------------------------------------------------------------------- #
#                                   COMMANDS                                   #
# ---------------------------------------------------------------------------- #

# Show available commands
default:
    @just list-all-skills

# Abort if the working tree has uncommitted changes
[private]
@_require-clean:
    git diff --quiet && git diff --cached --quiet || { echo 'Error: uncommitted changes in git' >&2; exit 1; }

# ---------------------------------------------------------------------------- #
#                                    CHECKS                                    #
# ---------------------------------------------------------------------------- #

# Check documentation and configuration formatting
@prettier-check +globs=prettier_globs:
    {{ prettier }} \
        --check \
        --cache \
        --cache-location {{ prettier_cache }} \
        --log-level warn \
        --no-error-on-unmatched-pattern \
        {{ globs }}

alias pc := prettier-check

# Format documentation and configuration
@prettier-write +globs=prettier_globs:
    {{ prettier }} \
        --write \
        --cache \
        --cache-location {{ prettier_cache }} \
        --log-level warn \
        --no-error-on-unmatched-pattern \
        {{ globs }}

alias pw := prettier-write

# Run staged-file checks
@pre-commit:
    sh .husky/pre-commit

alias precommit := pre-commit

# ---------------------------------------------------------------------------- #
#                                    SKILLS                                    #
# ---------------------------------------------------------------------------- #

# Skills synced from their own canonical sources rather than the catalog (must track `install-external`'s sync_skill calls)
external_skills := "chrome-devtools codebase-design find-skills"

# Print a colorized, titled list of skill names (or a "(none)" fallback)
[private]
[script("bash")]
_list-skills title *names:
    set -euo pipefail
    echo -e '{{ BOLD }}{{ GREEN }}● {{ title }}:{{ NORMAL }}'
    if [ -z "{{ names }}" ]; then
        echo -e '  {{ YELLOW }}(none){{ NORMAL }}'
    else
        for name in {{ names }}; do echo -e "  {{ CYAN }}▸ ${name}{{ NORMAL }}"; done
    fi

# List all installed skills
[group("skills")]
@list-all-skills:
    just _list-skills "Skills" $(ls -1 skills 2>/dev/null)

alias sl := list-all-skills
alias list := list-all-skills

# List externally managed skills (installed via install-external)
[group("skills")]
@list-external-skills:
    just _list-skills "External skills" {{ external_skills }}

# List catalog-managed skills (installed via install-catalog)
[group("skills")]
@list-catalog-skills:
    just _list-skills "Catalog skills" $(comm -23 <(ls -1 skills 2>/dev/null | sort) <(printf '%s\n' {{ external_skills }} | sort))

# Install or refresh externally managed skills from their canonical sources
[group("skills")]
[script("bash")]
install-external: _require-clean
    set -euo pipefail
    canonical_skills_dir="$HOME/.agents/skills"
    claude_skills_dir="$HOME/.claude/skills"

    command -v bunx >/dev/null 2>&1 || {
        echo "Error: required command not found: bunx" >&2
        exit 1
    }

    sync_skill() {
        source="$1"
        skill_name="$2"

        bunx skills add "$source" \
            --global \
            --agent claude-code codex \
            --skill "$skill_name" \
            --yes

        [[ -f "$canonical_skills_dir/$skill_name/SKILL.md" ]] || {
            echo "Error: $skill_name missing from the universal install" >&2
            exit 1
        }
        [[ -f "$claude_skills_dir/$skill_name/SKILL.md" ]] || {
            echo "Error: $skill_name missing from the Claude Code install" >&2
            exit 1
        }
    }

    sync_skill "ChromeDevTools/chrome-devtools-mcp" "chrome-devtools"
    sync_skill "mattpocock/skills" "codebase-design"
    sync_skill "vercel-labs/skills" "find-skills"

    printf '{{ GREEN }}%s{{ NORMAL }}\n' "✅ Synced 3 externally managed skills"

alias ie := install-external

# Install catalog skills from a repo
# Stale upstream skill pruning is tracked upstream: https://github.com/vercel-labs/skills/issues/415
[group("skills")]
[script("bash")]
install-catalog repo="PaulRBerg/agent-skills": _require-clean
    set -euo pipefail
    repo='{{ repo }}'
    claude_skills_dir="$HOME/.claude/skills"
    canonical_skills_dir="$HOME/.agents/skills"
    codex_skills_dir="$HOME/.codex/skills"

    for command_name in bunx gum yq; do
        command -v "$command_name" >/dev/null 2>&1 || {
            echo "Error: required command not found: $command_name" >&2
            exit 1
        }
    done

    stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/skills-install.XXXXXX")"
    staged_claude_dir="$stage_dir/claude"
    staged_state_dir="$stage_dir/state"
    cleanup() {
        rm -rf "$stage_dir"
    }
    trap cleanup EXIT

    gum spin \
        --title "Resolving skill targets from $repo..." \
        --show-error \
        -- env CLAUDE_CONFIG_DIR="$staged_claude_dir" XDG_STATE_HOME="$staged_state_dir" \
        bunx skills add "$repo" \
        --global \
        --agent claude-code \
        --skill '*' \
        --yes

    skill_files=("$staged_claude_dir"/skills/*/SKILL.md)
    [[ -f "${skill_files[0]}" ]] || {
        echo "Error: no skills discovered in $repo" >&2
        exit 1
    }

    shared=()
    claude_only=()
    codex_only=()
    restricted=()

    for skill_file in "${skill_files[@]}"; do
        skill_name="$(basename "$(dirname "$skill_file")")"
        targets="$(yq --front-matter=extract -r '.metadata."install-targets" // "claude-code codex"' "$skill_file")"

        case "$targets" in
        "claude-code codex")
            shared+=("$skill_name")
            ;;
        "claude-code")
            claude_only+=("$skill_name")
            restricted+=("$skill_name")
            ;;
        "codex")
            codex_only+=("$skill_name")
            restricted+=("$skill_name")
            ;;
        *)
            echo "Error: $skill_name has invalid metadata.install-targets: $targets" >&2
            exit 1
            ;;
        esac
    done

    mkdir -p "$claude_skills_dir"
    find "$claude_skills_dir" -maxdepth 1 -type l ! -exec test -e {} \; -delete

    if ((${#restricted[@]})); then
        gum spin \
            --title "Removing stale restricted skill installations..." \
            --show-error \
            -- bunx skills remove \
            --global \
            --skill "${restricted[@]}" \
            --yes
    fi

    if ((${#shared[@]})); then
        gum spin \
            --title "Installing ${#shared[@]} shared skills..." \
            --show-error \
            -- bunx skills add "$repo" \
            --global \
            --agent claude-code codex \
            --skill "${shared[@]}" \
            --yes
    fi

    if ((${#claude_only[@]})); then
        gum spin \
            --title "Installing ${#claude_only[@]} Claude-only skills..." \
            --show-error \
            -- bunx skills add "$repo" \
            --global \
            --agent claude-code \
            --skill "${claude_only[@]}" \
            --yes
    fi

    if ((${#codex_only[@]})); then
        gum spin \
            --title "Installing ${#codex_only[@]} Codex-only skills..." \
            --show-error \
            -- bunx skills add "$repo" \
            --global \
            --agent codex \
            --skill "${codex_only[@]}" \
            --yes
    fi

    for skill_name in "${shared[@]}"; do
        [[ -f "$canonical_skills_dir/$skill_name/SKILL.md" ]] || {
            echo "Error: shared skill missing from universal install: $skill_name" >&2
            exit 1
        }
        [[ -f "$claude_skills_dir/$skill_name/SKILL.md" ]] || {
            echo "Error: shared skill missing from Claude Code: $skill_name" >&2
            exit 1
        }
    done

    for skill_name in "${claude_only[@]}"; do
        [[ -f "$claude_skills_dir/$skill_name/SKILL.md" && ! -L "$claude_skills_dir/$skill_name" ]] || {
            echo "Error: Claude-only skill is not a direct Claude install: $skill_name" >&2
            exit 1
        }
        [[ ! -e "$canonical_skills_dir/$skill_name" && ! -L "$canonical_skills_dir/$skill_name" ]] || {
            echo "Error: Claude-only skill leaked into the universal install: $skill_name" >&2
            exit 1
        }
        [[ ! -e "$codex_skills_dir/$skill_name" && ! -L "$codex_skills_dir/$skill_name" ]] || {
            echo "Error: Claude-only skill leaked into Codex: $skill_name" >&2
            exit 1
        }
    done

    for skill_name in "${codex_only[@]}"; do
        [[ -f "$canonical_skills_dir/$skill_name/SKILL.md" || -f "$codex_skills_dir/$skill_name/SKILL.md" ]] || {
            echo "Error: Codex-only skill missing from Codex: $skill_name" >&2
            exit 1
        }
        [[ ! -e "$claude_skills_dir/$skill_name" && ! -L "$claude_skills_dir/$skill_name" ]] || {
            echo "Error: Codex-only skill leaked into Claude Code: $skill_name" >&2
            exit 1
        }
    done

    dangling_link="$(find "$claude_skills_dir" -maxdepth 1 -type l ! -exec test -e {} \; -print -quit)"
    [[ -z "$dangling_link" ]] || {
        echo "Error: dangling Claude skill link remains: $dangling_link" >&2
        exit 1
    }

    printf '{{ GREEN }}%s{{ NORMAL }}\n' \
        "✅ Installed ${#shared[@]} shared, ${#claude_only[@]} Claude-only, and ${#codex_only[@]} Codex-only skills from $repo"

alias ic := install-catalog

# Purge all skills and print reinstall commands
[confirm("This will purge all skills. Continue? [y/N]")]
[group("skills")]
[script("bash")]
reset-skills: _require-clean
    set -euo pipefail
    bunx skills remove --all --global --yes > /dev/null
    echo ""
    echo "Skills purged. Run these commands to reinstall:"
    echo ""
    echo "  just install-catalog"
    echo "  just install-external"

alias rs := reset-skills
