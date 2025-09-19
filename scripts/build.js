import { build } from 'esbuild';
import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs/promises';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');
const outDir = path.join(projectRoot, 'app/js/dist');

async function main() {
  await fs.mkdir(outDir, { recursive: true });
  await build({
    entryPoints: [path.join(projectRoot, 'app/js/app.js')],
    bundle: true,
    format: 'iife',
    platform: 'browser',
    target: ['es2018'],
    outfile: path.join(outDir, 'app.bundle.js'),
    sourcemap: true,
    logLevel: 'info',
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
