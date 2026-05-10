/**
 * Codai Plugins — OpenCode plugin
 *
 * - Registers the skills/ directory so OpenCode discovers all codai skills.
 * - Injects absolute paths to each plugin's run.sh into the first user message
 *   so the AI uses correct paths regardless of the current project directory.
 */

import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SKILLS_DIR = path.resolve(__dirname, '../../skills');

let _contextCache = undefined;

const buildContext = () => {
  if (_contextCache !== undefined) return _contextCache;

  const lines = [];
  try {
    const entries = fs.readdirSync(SKILLS_DIR, { withFileTypes: true });
    for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
      if (!entry.isDirectory()) continue;
      const runSh = path.join(SKILLS_DIR, entry.name, 'run.sh');
      if (fs.existsSync(runSh)) {
        lines.push(`  ${entry.name}: ${runSh}`);
      }
    }
  } catch {
    _contextCache = null;
    return null;
  }

  if (!lines.length) {
    _contextCache = null;
    return null;
  }

  _contextCache = `<codai-plugin-paths>
Plugin root: ${SKILLS_DIR}

Absolute paths to plugin scripts:
${lines.join('\n')}

IMPORTANT: When executing any codai plugin command, use the absolute path above — never use \`./run.sh\` (relative paths fail outside the plugin directory).
</codai-plugin-paths>`;

  return _contextCache;
};

export const CodaiPlugin = async ({ client, directory }) => {
  return {
    // Register skills directory so OpenCode discovers all SKILL.md files
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(SKILLS_DIR)) {
        config.skills.paths.push(SKILLS_DIR);
      }
    },

    // Inject absolute script paths into the first user message of each session
    'experimental.chat.messages.transform': async (_input, output) => {
      const context = buildContext();
      if (!context || !output.messages.length) return;

      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;

      // Idempotency guard — skip if already injected
      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('codai-plugin-paths'))) return;

      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: context });
    }
  };
};
