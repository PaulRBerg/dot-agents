# Skill Maintenance

Read this before repairing one of my personal skills under the continuous skill maintenance authorization in
`~/.agents/AGENTS.md`, when an `ai-*` CLI is missing, or when you need to locate or validate skill installations.

## Tooling

The `ai-commit`, `ai-coord`, `ai-handoff`, `ai-notify`, and `ai-skillet` CLIs that the global instructions and skills
use live in `~/projects/agent-skills/toolkit/`. Run `just toolkit::install-cli` there to install or refresh them.

To find where skills are installed, duplicated, or referenced, run `ai-skillet map` instead of manually scanning `~`. To
validate skill metadata, run `ai-skillet doctor --root <dir>`. Read each command's `--help` first. It documents scan
defaults and exclusions, when to pass `--root` or `--portfolio-root`, the `--fix-safe` boundary, and exit codes.

## Repair Procedure

- Verify the issue against current evidence and the catalog source. One verified occurrence is enough. Distinguish skill
  defects from transient failures and project-specific conventions. Keep corrections reusable and based on the observed
  need. If the source already contains the correction, refresh the installation through the publish workflow.
- Read the source repository's instructions and follow the Autonomous maintenance lifecycle in `~/.agents/AGENTS.md`. A
  blocked main task does not prevent independent skill repairs.
- Update the owning instructions, references, or helpers in the source catalog. Then validate, commit, push, and publish
  them to the skill's declared installations. Use the corrected source guidance for the rest of the session.
- A local workaround does not complete the work. A skill's fixed-scope workflow or recommendation-only ending does not
  cancel this authorization. Finish that workflow, then make the repair as separate maintenance.
- Preserve the skill's purpose and existing approval boundaries. Keep improvements tied to actual use. Do not turn
  routine maintenance into a catalog audit or speculative feature work.
