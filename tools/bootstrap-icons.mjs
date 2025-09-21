import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..');
const manifestPath = resolve(here, 'app-icon-manifest.json');
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));

const entries = Object.entries(manifest);
for (const [relativePath, base64] of entries) {
  const target = resolve(repoRoot, relativePath);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, Buffer.from(base64, 'base64'));
}

console.log(`Restored ${entries.length} app icon asset files.`);
