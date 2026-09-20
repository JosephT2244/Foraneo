// Cache only this app's public files. Profiles/photos stay in browser storage,
// never in the shared service-worker cache. Scope also works under /Foraneo/.
const ROOT = new URL('./', self.location.href);
const PREFIX = 'foraneo-v3-' + encodeURIComponent(ROOT.pathname) + '-';
// The production build replaces this token with its content hash.
const CACHE = PREFIX + '__FORANEO_BUILD_ID__';
const SHELL = ['./', './index.html', './manifest.webmanifest', './favicon.png', './icon-192.png', './icon-512.png', './photos/pasta.jpg', './photos/avena.jpg', './photos/arroz.jpg', './photos/tacos.jpg', './photos/ensalada.jpg'];
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await cache.addAll(SHELL.map(path => new URL(path, ROOT).href));
    // Precache generated entry modules on the FIRST visit, before SW control.
    const html = await (await cache.match(new URL('./index.html', ROOT))).text();
    const assets = [...html.matchAll(/(?:src|href)=["']([^"']+\.(?:js|css))["']/g)]
      .map(match => new URL(match[1], ROOT))
      .filter(url => url.origin === ROOT.origin && url.pathname.startsWith(ROOT.pathname));
    await cache.addAll(assets.map(url => url.href));
    await self.skipWaiting();
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith(PREFIX) && key !== CACHE).map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  const request = event.request, url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== ROOT.origin || !url.pathname.startsWith(ROOT.pathname)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(request);
    // Hashed Vite assets never change in place; everything else is network-first.
    if (cached && /\/assets\/[^/]+-[\w-]+\.(?:js|css)$/.test(url.pathname)) return cached;
    try {
      const response = await fetch(request);
      // Navigation stays on the atomically installed shell. A new build gets
      // its own worker/cache only after all its entry assets were downloaded.
      if (response.ok && response.type === 'basic' && request.mode !== 'navigate' && !/\/index\.html$/.test(url.pathname)) await cache.put(request, response.clone());
      return response;
    } catch {
      if (cached) return cached;
      if (request.mode === 'navigate') {
        const shell = await cache.match(new URL('./index.html', ROOT));
        if (shell) return shell;
      }
      return new Response('Este recurso no está disponible sin conexión.', {status:503,headers:{'Content-Type':'text/plain;charset=utf-8'}});
    }
  })());
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({type:'window',includeUncontrolled:true});
    const current = windows.find(client => client.url.startsWith(ROOT.href));
    if (current) return current.focus();
    return self.clients.openWindow(ROOT.href);
  })());
});
