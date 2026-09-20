import { defineConfig } from 'vite';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

// Include the source worker and every emitted module in the cache version.
// Vite's public files are copied after generateBundle; patch only the built
// worker in writeBundle, leaving the source tree unchanged.
function versionOfflineCache() {
  let buildId;
  return {
    name: 'foraneo-offline-cache-version',
    apply: 'build',
    generateBundle(_options, bundle) {
      const hash = createHash('sha256').update(readFileSync(new URL('./public/sw.js', import.meta.url)));
      for (const [name, item] of Object.entries(bundle).sort(([a], [b]) => a.localeCompare(b))) {
        hash.update(name).update(item.type === 'chunk' ? item.code : item.source);
      }
      buildId = hash.digest('hex').slice(0, 16);
    },
    writeBundle(options) {
      const target = resolve(options.dir, 'sw.js');
      writeFileSync(target, readFileSync(target, 'utf8').replace('__FORANEO_BUILD_ID__', buildId));
    }
  };
}

export default defineConfig({
  base: process.env.VITE_BASE_PATH || '/',
  plugins: [versionOfflineCache()],
  build: { sourcemap: false }
});
