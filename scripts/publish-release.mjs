// Maintainer tool: use the Git credential configured for this repository only.
// Credentials stay in memory; credential-helper errors are deliberately redacted.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFile, stat } from 'node:fs/promises';

const repository = 'JosephT2244/Foraneo';
const sha256 = body => createHash('sha256').update(body).digest('hex');

async function main() {
  const args = process.argv.slice(2);
  const tag = args.find(argument => !argument.startsWith('--')) || 'v2.0.0';
  if (!/^v\d+\.\d+\.\d+$/.test(tag)) throw new Error('Use a semantic version tag.');
  if (args.some(argument => argument.startsWith('--') && !['--check', '--configure-pages'].includes(argument))) throw new Error('Unknown release option.');
  if (args.includes('--check') && args.includes('--configure-pages')) throw new Error('Choose --check or --configure-pages, not both.');
  const remote = execFileSync('git', ['remote', 'get-url', 'origin'], { encoding: 'utf8' }).trim();
  if (remote.toLowerCase() !== `https://github.com/${repository}.git`.toLowerCase()) throw new Error('Repository origin differs; no upload performed.');
  let raw;
  try {
    raw = execFileSync('git', ['credential', 'fill'], { input: `protocol=https\nhost=github.com\npath=${repository}.git\n\n`, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env, GCM_INTERACTIVE: 'never', GIT_TERMINAL_PROMPT: '0' } });
  } catch {
    // Never print the original Error: its stdout/stderr buffers can hold a token.
    throw new Error('Could not read the repository credential. No upload performed.');
  }
  const credentials = Object.fromEntries(raw.trim().split(/\r?\n/).filter(line => line.includes('=')).map(line => { const index = line.indexOf('='); return [line.slice(0, index), line.slice(index + 1)]; }));
  if (!credentials.password) throw new Error('No repository credential available.');
  const headers = { Authorization: `Bearer ${credentials.password}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'Foraneo-Release' };
  async function api(path, options = {}) {
    const response = await fetch(`https://api.github.com/repos/${repository}${path}`, { ...options, headers: { ...headers, ...options.headers } });
    if (response.status === 404) return null;
    if (!response.ok) throw new Error(`GitHub request failed with HTTP ${response.status}`);
    return response.status === 204 ? {} : response.json();
  }
  async function findRelease() {
    const published = await api(`/releases/tags/${tag}`);
    if (published) return published;
    // Authenticated listings include drafts even when the tag endpoint does not.
    for (let page = 1; ; page++) {
      const releases = await api(`/releases?per_page=100&page=${page}`);
      if (!Array.isArray(releases)) throw new Error('Could not inspect existing releases.');
      const draft = releases.find(release => release.tag_name === tag);
      if (draft) return draft;
      if (releases.length < 100) return null;
    }
  }
  if (args.includes('--check')) {
    const pages = await api('/pages');
    const release = await findRelease();
    console.log(JSON.stringify({ authenticated: true, pages: pages && { url: pages.html_url, buildType: pages.build_type, status: pages.status, source: pages.source }, existingRelease: release && { url: release.html_url, draft: release.draft, assets: release.assets.map(asset => asset.name) } }, null, 2));
    return;
  }
  if (args.includes('--configure-pages')) {
    const configured = await api('/pages', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ build_type: 'workflow' }) });
    if (!configured) throw new Error('GitHub Pages was not found; no configuration was changed.');
    console.log('GitHub Pages configured to use the repository deployment workflow.');
    return;
  }
  const files = ['foraneo.apk', 'foraneo.exe', 'foraneo-windows-portable.zip', 'SHA256SUMS.txt'];
  for (const name of files) {
    const entry = await stat(`artifacts/${name}`);
    if (!entry.isFile() || entry.size === 0) throw new Error(`Missing or empty release artifact: ${name}`);
  }
  let release = await findRelease();
  if (release && !release.draft) throw new Error(`Release ${tag} is already published. Refusing any modification; use a new version.`);
  const commit = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
  if (release && /^[a-f0-9]{40}$/i.test(release.target_commitish) && release.target_commitish !== commit) throw new Error('The draft belongs to a different commit. Keep it unchanged and use a new version.');
  const checksums = new Map((await readFile('artifacts/SHA256SUMS.txt', 'utf8')).trim().split(/\r?\n/).map(line => {
    const match = /^([a-f\d]{64})\s+\*?(.+)$/i.exec(line);
    if (!match) throw new Error('Malformed SHA256SUMS.txt; package the release again.');
    return [match[2], match[1].toLowerCase()];
  }));
  const payloads = new Map();
  for (const name of files) {
    const body = await readFile(`artifacts/${name}`);
    const digest = sha256(body);
    if (name !== 'SHA256SUMS.txt' && checksums.get(name) !== digest) throw new Error(`Checksum mismatch for ${name}; no upload performed.`);
    payloads.set(name, { body, digest });
  }
  async function verifyExisting(asset, name) {
    const { body, digest } = payloads.get(name);
    if (asset.state !== 'uploaded' || asset.size !== body.length) throw new Error(`Draft asset ${name} is incomplete or differs in size; no overwrite performed.`);
    let remoteDigest;
    if (/^sha256:[a-f\d]{64}$/i.test(asset.digest || '')) {
      remoteDigest = asset.digest.slice(7).toLowerCase();
    } else {
      const response = await fetch(`https://api.github.com/repos/${repository}/releases/assets/${asset.id}`, { headers: { ...headers, Accept: 'application/octet-stream' } });
      if (!response.ok || !response.body || response.headers.get('content-type')?.includes('application/json')) throw new Error(`Could not verify draft asset ${name}; no overwrite performed.`);
      const hash = createHash('sha256');
      let bytes = 0;
      for await (const chunk of response.body) {
        bytes += chunk.length;
        if (bytes > body.length) throw new Error(`Draft asset ${name} differs in size; no overwrite performed.`);
        hash.update(chunk);
      }
      if (bytes !== body.length) throw new Error(`Draft asset ${name} differs in size; no overwrite performed.`);
      remoteDigest = hash.digest('hex');
    }
    if (remoteDigest !== digest) throw new Error(`Draft asset ${name} has different content; no overwrite performed. Use a new version or recover the draft manually.`);
  }
  // Verify every existing asset before adding files; never mutate published releases.
  const verifiedNames = new Set();
  for (const asset of release?.assets || []) {
    if (!files.includes(asset.name)) throw new Error(`Draft contains unexpected asset ${asset.name}; inspect it manually before publishing.`);
    if (verifiedNames.has(asset.name)) throw new Error(`Draft has duplicate asset ${asset.name}; inspect it manually.`);
    await verifyExisting(asset, asset.name);
    verifiedNames.add(asset.name);
  }
  if (!release) release = await api('/releases', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ tag_name: tag, target_commitish: commit, name: `Foráneo ${tag.slice(1)}`, draft: true, prerelease: false, body: 'Foráneo offline: recetario detallado, despensa, compras, agenda, perfil local cifrado, modo oscuro y logo oficial.\n\nAndroid: APK firmado, cámara, recordatorios locales y cuatro widgets de inicio. Windows: instalador por usuario y versión portable completa.\n\nNo usa APIs de IA ni servicios de pago. Google Calendar y YouTube se abren sólo por acción del usuario. Las cuentas son locales; no hay sincronización cloud. En web y Windows los avisos programados necesitan la app abierta. No hay instalable iOS.\n\nComprueba SHA256SUMS.txt. Windows puede advertir editor desconocido porque no hay certificado comercial Authenticode. Conserva tus respaldos antes de actualizar.' }) });
  if (!release?.draft || !release.upload_url) throw new Error('A valid draft release could not be created.');
  for (const name of files) {
    if (verifiedNames.has(name)) { console.log(`Verified existing draft asset ${name}; skipped upload.`); continue; }
    const { body } = payloads.get(name);
    const upload = new URL(release.upload_url.replace(/\{.*$/, ''));
    if (upload.protocol !== 'https:' || upload.hostname !== 'uploads.github.com') throw new Error('Unexpected GitHub upload host; no credentials sent.');
    upload.searchParams.set('name', name);
    const response = await fetch(upload, { method: 'POST', headers: { ...headers, 'Content-Type': name.endsWith('.txt') ? 'text/plain' : 'application/octet-stream', 'Content-Length': String(body.length) }, body });
    if (!response.ok) throw new Error(`Uploading ${name} failed with HTTP ${response.status}; draft preserved. Run the same command to verify and resume.`);
    console.log(`Uploaded ${name} (${body.length} bytes)`);
  }
  const published = await api(`/releases/${release.id}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ draft: false }) });
  if (!published || published.draft) throw new Error('GitHub did not confirm publication; the draft is preserved.');
  console.log(`Published https://github.com/${repository}/releases/tag/${tag}`);
}

// Return normally so Node can drain fetch/stdio handles on Windows.
// Calling process.exit() here can trigger a libuv UV_HANDLE_CLOSING assertion.
main().catch(error => {
  console.error(error instanceof Error ? error.message : 'Release operation failed.');
  process.exitCode = 1;
});
