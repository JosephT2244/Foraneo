import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const source = readFileSync(new URL('../public/sw.js', import.meta.url), 'utf8');
function worker() {
  const listeners = new Map(), stores = new Map();
  const root = 'https://example.test/Foraneo/';
  const key = request => typeof request === 'string' ? request : request.url || request.href;
  let online = true;
  const fetch = async request => {
    if (!online) throw new TypeError('Offline');
    const address = key(request);
    const response = new Response(address.endsWith('/index.html') || address === root
      ? '<script type="module" src="/Foraneo/assets/index-ABC123.js"></script><link rel="stylesheet" href="/Foraneo/assets/index-ABC123.css">'
      : 'A public application resource', { status: 200 });
    Object.defineProperty(response, 'type', { value: 'basic' });
    return response;
  };
  const caches = {
    keys: async () => [...stores.keys()],
    delete: async name => stores.delete(name),
    open: async name => {
      if (!stores.has(name)) stores.set(name, new Map());
      const store = stores.get(name);
      return {
        match: async request => store.get(key(request))?.clone(),
        put: async (request, response) => store.set(key(request), response),
        addAll: async requests => { for (const request of requests) store.set(key(request), await fetch(request)); },
      };
    },
  };
  const self = {
    location: { href: root + 'sw.js' },
    addEventListener: (type, listener) => listeners.set(type, listener),
    skipWaiting: async () => {},
    clients: { claim: async () => {}, matchAll: async () => [], openWindow: async () => {} },
  };
  runInNewContext(source, { self, caches, fetch, URL, Response, encodeURIComponent });
  return {
    root, stores, setOffline: () => { online = false; },
    async lifecycle(name) { let waiting; listeners.get(name)({ waitUntil: promise => { waiting = promise; } }); await waiting; },
    async request(path, mode = 'cors') {
      let response;
      listeners.get('fetch')({ request: { url: new URL(path, root).href, method: 'GET', mode }, respondWith: promise => { response = promise; } });
      return response;
    },
  };
}

test('first install caches hashed JS/CSS and illustrations for a complete offline shell', async () => {
  const instance = worker();
  await instance.lifecycle('install');
  instance.setOffline();
  assert.equal((await instance.request('./', 'navigate')).status, 200);
  assert.equal((await instance.request('assets/index-ABC123.js')).status, 200);
  assert.equal((await instance.request('assets/index-ABC123.css')).status, 200);
  assert.equal((await instance.request('photos/pasta.jpg')).status, 200);
  assert.equal((await instance.request('unknown-page', 'navigate')).status, 200);
  const missing = await instance.request('photos/does-not-exist.jpg');
  assert.equal(missing.status, 503);
  assert.doesNotMatch(await missing.text(), /<script/);
});

test('worker leaves sibling apps, cross-origin requests and their caches untouched', async () => {
  const instance = worker();
  instance.stores.set('another-application-cache', new Map());
  instance.stores.set('foraneo-v3-%2FOtherApp%2F-older', new Map());
  instance.stores.set('foraneo-v3-%2FForaneo%2F-older', new Map());
  await instance.lifecycle('install');
  await instance.lifecycle('activate');
  assert.equal(instance.stores.has('another-application-cache'), true);
  assert.equal(instance.stores.has('foraneo-v3-%2FOtherApp%2F-older'), true);
  assert.equal(instance.stores.has('foraneo-v3-%2FForaneo%2F-older'), false);
  assert.equal(await instance.request('https://external.test/image.png'), undefined);
  assert.equal(await instance.request('/OtherApp/'), undefined);
});
