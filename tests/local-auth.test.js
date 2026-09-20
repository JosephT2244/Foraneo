import test from 'node:test';
import assert from 'node:assert/strict';
import { LocalAuth, validateVault } from '../src/local-auth.js';
import { weekDates, calendarUrl, calendarIcs } from '../src/agenda.js';
test('local vault encrypts, preserves empty arrays, rejects incorrect passwords and unlocks', async () => {
  const values = new Map(); const storage = { getItem: key => values.get(key), setItem: (key, value) => values.set(key, value) };
  const auth = new LocalAuth(storage);
  await auth.create('Joseph', 'correcta-segura-123', { products: [], secret: 'Texto privado' });
  assert.ok(!auth.export().includes('Texto privado'));
  const other = new LocalAuth(storage);
  await assert.rejects(other.unlock('Joseph', 'incorrecta'));
  assert.deepEqual(await other.unlock('Joseph', 'correcta-segura-123'), { products: [], secret: 'Texto privado' });
  other.lock(); await assert.rejects(other.save({}));
});
test('calendar uses local week boundaries and escapes calendar data', () => {
  assert.deepEqual(weekDates('2026-09-13'), ['2026-09-07', '2026-09-08', '2026-09-09', '2026-09-10', '2026-09-11', '2026-09-12', '2026-09-13']);
  const task = { id: '1', title: 'Comprar, limpiar; cocinar', date: '2026-09-12', time: '10:30', notes: 'Línea 1\nLínea 2' };
  assert.equal(new URL(calendarUrl(task)).searchParams.get('text'), task.title);
  assert.match(calendarIcs([task]), /Comprar\\, limpiar\\; cocinar/);
});

test('encrypted saves snapshot edits and serialize concurrent writes', async () => {
  const values = new Map(); const storage = { getItem: key => values.get(key), setItem: (key, value) => values.set(key, value) };
  const auth = new LocalAuth(storage);
  await auth.create('Joseph', 'correcta-segura-123', { count: 0 });
  const first = { count: 1 };
  const saving = auth.save(first);
  first.count = 999;
  await saving;
  assert.deepEqual(await new LocalAuth(storage).unlock('Joseph', 'correcta-segura-123'), { count: 1 });
  await Promise.all([auth.save({ count: 2, body: 'a'.repeat(1000000) }), auth.save({ count: 3 })]);
  assert.deepEqual(await new LocalAuth(storage).unlock('Joseph', 'correcta-segura-123'), { count: 3 });
  const vault = JSON.parse(auth.export());
  assert.throws(() => validateVault({ ...vault, username: ' ' }), /no es válido/);
  assert.throws(() => validateVault({ ...vault, ciphertext: '%%%%' }), /no es válido/);
  assert.throws(() => validateVault({ ...vault, iterations: 1000000000 }), /no es válido/);
});

test('failed password change preserves the previous usable encrypted profile', async () => {
  let saved, fail = false;
  const storage = { getItem: () => saved, setItem: (_key, value) => { if (fail) throw new Error('Quota exceeded'); saved = value; } };
  const auth = new LocalAuth(storage);
  await auth.create('Joseph', 'correcta-segura-123', { products: [] });
  fail = true;
  await assert.rejects(auth.create('Joseph', 'contraseña-nueva-123', { products: [] }), /Quota/);
  fail = false;
  await auth.save({ products: [], retained: true });
  assert.deepEqual(await new LocalAuth(storage).unlock('Joseph', 'correcta-segura-123'), { products: [], retained: true });
});
