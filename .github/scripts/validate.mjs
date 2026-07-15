// Validates the marketplace, every plugin manifest, and every skill.
// No external dependencies; runs on a stock Node.js runner.
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const errors = [];
const err = (m) => errors.push(m);
const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));

// 1. Marketplace manifest
const mktPath = '.claude-plugin/marketplace.json';
if (!existsSync(mktPath)) err(`missing ${mktPath}`);
const mkt = existsSync(mktPath) ? readJson(mktPath) : { plugins: [] };
if (!mkt.name) err('marketplace.json: missing "name"');
if (!Array.isArray(mkt.plugins) || mkt.plugins.length === 0)
  err('marketplace.json: "plugins" must be a non-empty array');

// 2. Each plugin
for (const entry of mkt.plugins ?? []) {
  const where = `plugin "${entry.name ?? '?'}"`;
  if (!entry.name) err(`${where}: missing "name"`);
  if (!entry.source) err(`${where}: missing "source"`);
  if (!entry.source) continue;

  const manifestPath = join(entry.source, '.claude-plugin', 'plugin.json');
  if (!existsSync(manifestPath)) {
    err(`${where}: source does not resolve to ${manifestPath}`);
    continue;
  }
  const manifest = readJson(manifestPath);
  for (const field of ['name', 'description', 'version'])
    if (!manifest[field]) err(`${manifestPath}: missing "${field}"`);
  if (manifest.name && entry.name && manifest.name !== entry.name)
    err(`${where}: marketplace name != plugin.json name ("${manifest.name}")`);

  // 3. Each skill in the plugin
  const skillsDir = join(entry.source, 'skills');
  if (existsSync(skillsDir)) {
    const { readdirSync } = await import('node:fs');
    for (const dir of readdirSync(skillsDir, { withFileTypes: true })) {
      if (!dir.isDirectory()) continue;
      const skillPath = join(skillsDir, dir.name, 'SKILL.md');
      if (!existsSync(skillPath)) {
        err(`${where}: skill "${dir.name}" missing SKILL.md`);
        continue;
      }
      const md = readFileSync(skillPath, 'utf8');
      const fm = md.match(/^---\n([\s\S]*?)\n---/);
      if (!fm) {
        err(`${skillPath}: missing YAML frontmatter`);
        continue;
      }
      if (!/^name:\s*\S/m.test(fm[1])) err(`${skillPath}: frontmatter missing "name"`);
      if (!/^description:\s*\S/m.test(fm[1]))
        err(`${skillPath}: frontmatter missing "description"`);
    }
  }
}

if (errors.length) {
  console.error('✗ validation failed:');
  for (const e of errors) console.error('  - ' + e);
  process.exit(1);
}
console.log('✓ marketplace, plugins, and skills are valid');
