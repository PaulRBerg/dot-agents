# Create AGENTS.md Files

Use `agents-brain create-agents-md [path] [--root-only] [--dry-run] [--force]` to initialize AGENTS.md files for a
scope. Create the scope-root file. Then judge each subtree on its own evidence. Create a nested file only where the
subtree needs one.

Follow user instructions and established authorization in SKILL.md. Apply its shared prompting and STE requirements, the
Repository Guard Rail, and Claude Code Compatibility. This route owns its scope, workflow, validation, and report. The
`maintain` discovery and report contract do not apply.

An explicit invocation of this route is the explicit request for broad context creation that
[create-docs.md](create-docs.md) requires before it creates nested AGENTS.md files. This route replaces the automatic
package-root rule of that reference with the per-subtree decision below.

Success means the scope root has an AGENTS.md, each nested AGENTS.md holds a real local delta, and every created claim
is verified against the repository.

## Contents

- [Arguments](#arguments)
- [Scope](#1-resolve-the-scope)
- [Evidence](#2-collect-evidence)
- [Nested decisions](#3-decide-nested-files)
- [Content](#4-write-the-files)
- [Verification and report](#5-verify-and-report)

## Arguments

- `path` (optional): A repository-relative directory. When omitted, use the invocation working directory. Do not
  redirect a nested invocation to the repository root.
- `--root-only`: Create only the scope-root AGENTS.md. Report nested candidates without writing them.
- `--dry-run`: Report planned files, nested decisions, and section-level previews. Write nothing.
- `--force`: Regenerate existing AGENTS.md targets in the scope. Never applies to deletions or to regular CLAUDE.md
  files.

Report unrecognized flags. Continue only when they cannot change scope, safety, or write behavior.

## Workflow

### 1. Resolve the Scope

Run the Repository Guard Rail from SKILL.md. Set `<scope>` to the resolved `path` or the invocation working directory.
Stop if `<scope>` is outside `repo_root` or inside an excluded installed `skills/` tree.

Read every AGENTS.md and CLAUDE.md from `repo_root` down to `<scope>`, and every existing AGENTS.md below `<scope>`. A
new file states only its delta from this chain. Classify each existing target as missing, existing, or blocked by a
regular CLAUDE.md. Without `--force`, leave existing AGENTS.md files untouched. Recommend `maintain` for their drift.

### 2. Collect Evidence

Use git-aware discovery. Exclude VCS, dependency, environment, build, vendored, and generated directories. Ground every
claim with the rules in the Ground the Content section of [create-docs.md](create-docs.md). Also collect these signals
for each candidate subtree:

- A manifest from the package-root list in [create-docs.md](create-docs.md), a workspace member, or a separate task
  runner.
- A language, framework, or toolchain different from its parent.
- Its own test, lint, build, codegen, or deploy command, or a different order or environment for a shared command.
- A generated-file boundary, a vendored tree, or an ownership rule.
- A safety, credential, financial, data-handling, migration, or external-system constraint.
- A review or release workflow that applies only to that subtree.

Inspect only the directories that these signals identify. Do not read every leaf directory.

### 3. Decide Nested Files

Create a nested AGENTS.md only when both conditions hold:

- The subtree has at least one verified signal from step 2 that changes how an agent works inside it.
- Its delta needs more than two short rules in the parent file, or it would mislead agents that work elsewhere.

Otherwise, put the rule in the nearest parent file and name the path it applies to. Apply these defaults:

- Put rules that many sibling packages share in their common parent. Do not create one file per identical workspace
  member.
- Do not create a file for a directory that only holds source files with no local rules.
- Prefer the shallowest directory that covers the whole delta. Create deeper files only for deeper deltas.
- For a generated or vendored tree, put the do-not-edit rule in the parent file. Do not create a file inside the tree.

Agents load nested files differently. Claude Code loads a subdirectory AGENTS.md when it reads a file in that
subdirectory. Codex loads AGENTS.md files only from the project root down to its working directory. Codex also stops
adding files when their combined size reaches its configured limit (32 KiB by default). For these reasons, link each
nested AGENTS.md from the scope-root file with the condition that requires it, for example
``Before you edit `contracts/`, read `contracts/AGENTS.md`.`` Keep each file small.

With `--root-only`, record each positive decision as a recommendation.

### 4. Write the Files

Write every file with the rules in the Generate AGENTS.md section of [create-docs.md](create-docs.md). Apply these
additional rules:

- Make the scope-root file the map. It holds shared defaults and the links to nested files.
- Write only local deltas in nested files. Do not repeat parent rules.
- Use the same section name for the same role in sibling files.
- When evidence for a section is missing, omit the section. Do not write placeholders.

Handle CLAUDE.md with the Handle CLAUDE.md section of [create-docs.md](create-docs.md). Handle CONTRIBUTING.md with the
Handle CONTRIBUTING.md section. Never create README.md in this route.

### 5. Verify and Report

- Run repository-defined Markdown formatting and checks on the created files when they exist.
- Check that every command, path, script, recipe, and link in the created files exists.
- Check that every nested file is linked from the scope-root file.
- When `agents_md_native=true`, verify that no CLAUDE.md symlink remains in the scope. Otherwise, verify that every
  created symlink resolves to its sibling AGENTS.md.
- Complete the meaning and style review in [asd-ste100.md](asd-ste100.md) for every created file.

Lead with `### ✅ AGENTS.md created` only after writes and checks pass. Use
`### ⚠️ AGENTS.md created — validation failed`, `### 🔎 AGENTS.md preview — no files written`, or
`### ⛔ AGENTS.md blocked — no files written` when they apply. Follow with a tree of created paths and a table of nested
decisions. Give each considered subtree one row with its path, its decision (created, kept in parent, or recommended),
and the deciding evidence. End with the exact checks and outcomes.

Commit when the request or standing instructions authorize it. Otherwise, offer to commit. Do not ask again for
authorization already given.
