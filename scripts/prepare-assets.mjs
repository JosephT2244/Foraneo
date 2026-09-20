// Optional maintainer utility. App runtime uses bundled files, never this host.
import { mkdir, writeFile, copyFile } from 'node:fs/promises';

const photos = {
  pasta: 'photo-1621996346565-e3dbc646d9a9',
  avena: 'photo-1517673400267-0251440c45dc',
  tacos: 'photo-1565299585323-38d6b0865b47',
  arroz: 'photo-1512058564366-18510be2db19',
  ensalada: 'photo-1512621776951-a57141f2eefd',
};
await mkdir('public/photos', { recursive: true });
await mkdir('foraneo_flutter/assets/photos', { recursive: true });
await Promise.all(Object.entries(photos).map(async ([name, id]) => {
  const url = `https://images.unsplash.com/${id}?auto=format&fit=crop&w=960&q=78&fm=jpg`;
  const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
  if (!response.ok || !response.headers.get('content-type')?.startsWith('image/')) throw new Error(`Photo ${name}: HTTP ${response.status}`);
  const path = `public/photos/${name}.jpg`;
  await writeFile(path, new Uint8Array(await response.arrayBuffer()));
  await copyFile(path, `foraneo_flutter/assets/photos/${name}.jpg`);
  console.log(`Bundled ${path}`);
}));
