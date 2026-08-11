import path from "node:path";

const agentsSource = path.resolve("AGENTS.md");

/**
 * @type {import("lint-staged").Configuration}
 */
export default {
  "**/*.{md,json,jsonc,yaml,yml}":
    "bunx --no-install prettier --write --cache --cache-location .cache/prettier/.prettier-cache --log-level warn",
  // Rebuild Codex instructions when the root AGENTS.md changed, then commit
  // the regenerated AGENTS.md in ~/.codex and CLAUDE.md in ~/.claude if it's
  // the only thing dirty in those repos
  "./AGENTS.md": [
    () => `bash helpers/commit_codex_agents.sh ${JSON.stringify(agentsSource)}`,
    "bash helpers/commit_claude_repo.sh",
  ],
};
