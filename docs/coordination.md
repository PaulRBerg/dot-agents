# Coordination Edge Cases

Read this when an `ai-coord` command reports a blocker you cannot explain, when it prints a `stale-dirt` advisory, or
when the detached triager's limits matter. The routine coordination gate lives in `~/.agents/AGENTS.md`.

- `start` reconciles process liveness first. It then releases ownership, including residual dirt attribution, whose
  owner session is gone. Thus, a blocker naming a holder that `status` cannot show is an ai-coord bug. Report it with
  the `start` and `status` output instead of editing the ledger. Never reset the ledger or release a live or uncertain
  owner.
- On a `stale-dirt` advisory, preserve pre-existing hunks byte-for-byte. `ai-commit prepare` auto-excludes recorded
  baselines.
- The detached ai-coord triager runs only in repositories whose opt-in is committed at `HEAD`. That worker may verify or
  close stale, rejected, or duplicate findings and commit only mechanical documentation or typo fixes to local `main`.
  It must never push. Everything else becomes a decision-complete task handoff. These worker limits do not restrict
  discovering sessions acting under the autonomous maintenance policy.
