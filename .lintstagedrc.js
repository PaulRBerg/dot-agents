import { homedir } from 'node:os';
import path from 'node:path';

const codexJustfile = path.join(homedir(), '.codex', 'justfile');

/**
 * @type {import("lint-staged").Configuration}
 */
export default {
  '**/*.{md,json,jsonc,yaml,yml}':
    'bunx --no-install prettier --write --cache --cache-location .cache/prettier/.prettier-cache --log-level warn',
  // Rebuild Codex instructions when the root AGENTS.md changed, then commit
  // the regenerated AGENTS.md in ~/.codex and CLAUDE.md in ~/.claude if it's
  // the only thing dirty in those repos
  './AGENTS.md': [
    () => `just --justfile ${JSON.stringify(codexJustfile)} build`,
    'bash helpers/commit_codex_agents.sh',
    'bash helpers/commit_claude_repo.sh',
  ],
};
