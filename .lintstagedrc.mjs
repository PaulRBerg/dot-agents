import path from "node:path";

const agentsSource = path.resolve("AGENTS.md");

/**
 * @type {import("lint-staged").Configuration}
 */
export default {
  "**/*.{md,json,jsonc,yaml,yml}":
    "bunx --no-install prettier --write --cache --cache-location .cache/prettier/.prettier-cache --log-level warn",
  // Rebuild and commit generated Codex and Claude instructions when root
  // AGENTS.md changes, preserving unrelated work in the sibling repos.
  "./AGENTS.md": [
    () => `bash helpers/commit_codex_agents.sh ${JSON.stringify(agentsSource)}`,
    "bash helpers/commit_claude_repo.sh",
  ],
};
