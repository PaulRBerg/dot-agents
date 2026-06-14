# Skill Dependencies

Local skill inter-dependencies detected under `./skills` as of 2026-06-14.
Only dependencies on sibling skills in this repository are listed; external
CLIs, APIs, GitHub repos, and global skill locations are out of scope except
where a local skill explicitly probes or names the same sibling skill.

## Dependency Types

| Type        | Meaning                                                                      |
| ----------- | ---------------------------------------------------------------------------- |
| Required    | The source skill says the target sibling skill must be installed or invoked. |
| Conditional | The target skill is needed only for a mode, branch, or precondition.         |
| Preferred   | The target skill is the preferred local source, with a documented fallback.  |
| Optional    | The target skill is one permitted implementation path among alternatives.    |
| Related     | The source skill points to the target for deeper command syntax or patterns. |

## Direct Dependencies

| Source skill   | Depends on      | Type        | Evidence                                                                                                           |
| -------------- | --------------- | ----------- | ------------------------------------------------------------------------------------------------------------------ |
| `bump-release` | `commit`        | Conditional | If unrelated uncommitted changes exist before release, it says to run the `commit` skill first.                    |
| `cli-cast`     | `evm-chains`    | Preferred   | RPC setup says to resolve the chain with `$evm-chains` first; if unavailable, fall back to `references/chains.md`. |
| `code-polish`  | `code-simplify` | Required    | It requires `code-simplify` as a sibling skill and reads `../code-simplify/SKILL.md`.                              |
| `code-polish`  | `code-review`   | Required    | It requires `code-review` as a sibling skill and reads `../code-review/SKILL.md`.                                  |
| `debrief`      | `playground`    | Conditional | HTML mode requires `playground`; `--md` disables this dependency.                                                  |
| `evm-chains`   | `cli-cast`      | Optional    | Direct RPC fallback may use `cast` from the `cli-cast` skill, or `curl`.                                           |
| `work`         | `code-polish`   | Required    | The polish step is mandatory and invokes `code-polish`, or reads `../code-polish/SKILL.md` inline.                 |
| `yeet`         | `cli-gh`        | Related     | Its related-skills section says to activate `cli-gh` for detailed GitHub CLI syntax, flags, and patterns.          |

## Transitive Dependencies

| Source skill | Transitive dependency chain            |
| ------------ | -------------------------------------- |
| `work`       | `work -> code-polish -> code-simplify` |
| `work`       | `work -> code-polish -> code-review`   |

## Cycles And Soft Edges

- `cli-cast` and `evm-chains` form a soft cycle:
  - `cli-cast -> evm-chains` is preferred for chain metadata and RouteMesh support.
  - `evm-chains -> cli-cast` is optional for direct RPC fallback, because `curl` is also allowed.
- This is not a hard install cycle because both sides document fallbacks.

## Skills With No Local Skill Dependencies Detected

- `autoresearch`
- `bump-deps`
- `cli-gh`
- `cli-just`
- `code-review`
- `code-simplify`
- `coingecko-cli`
- `coingecko-historical`
- `commit`
- `create-skill`
- `effect-ts`
- `find-skills`
- `git-squash`
- `md-docs`
- `notion-cli`
- `pdf`
- `playground`
- `spreadsheets`
- `summarize`
- `tailwind-css`
- `todo-archive`
- `update-skills`
- `vitest`

## Not Counted

- `coingecko-historical` mentions the `cg` CLI, but does not name or load the
  local `coingecko-cli` skill. This is a tool dependency, not a skill
  dependency.
- `debrief` mentions the upstream Anthropic `playground` skill, but its helper
  script also probes local paths including `./.agents/skills/playground` and
  `~/.agents/skills/playground`. Because this repo has `./skills/playground`,
  it is counted as a local conditional dependency.
- Generic words that also happen to be skill names, such as `commit`,
  `playground`, and `work`, were ignored unless the source explicitly referred
  to a skill, sibling `SKILL.md`, or local skill path.
