import test from 'node:test';
import assert from 'node:assert/strict';
import { validateState, safePhoto, validDate } from '../src/state.js';

const empty = () => ({ products: [], recipes: [], tasks: [], shopping: [] });

test('restoring an empty household preserves empty lists instead of seeding examples', () => {
  const state = validateState(empty());
  for (const name of ['products', 'recipes', 'tasks', 'shopping']) assert.deepEqual(state[name], []);
  assert.throws(() => validateState({ products: [] }), /respaldo/);
  assert.throws(() => validateState({ ...empty(), tasks: Array(10001).fill({}) }), /demasiados/);
});

test('backup validation normalizes numeric values and rejects inherited category keys', () => {
  const state = validateState({ ...empty(), products: [
    { id: 'one', name: 'Producto', category: '__proto__', stock: -4, usualPrice: 'bad', contentValue: 0 },
    { id: 'one', name: 'Duplicado' },
    { id: 'two', name: 'Avena', category: 'comida', stock: '0.5', contentValue: 500, contentUnit: 'g' },
  ] });
  assert.equal(state.products.length, 2);
  assert.equal(state.products[0].category, 'otros');
  assert.equal(state.products[0].stock, 0);
  assert.equal(state.products[0].usualPrice, 0);
  assert.equal(state.products[0].contentValue, 1);
  assert.equal(state.products[1].stock, 0.5);
});

test('backup validation excludes executable image and video URLs and invalid dates', () => {
  assert.equal(safePhoto('javascript:alert(1)'), '');
  assert.equal(safePhoto('data:image/svg+xml;base64,PHN2Zy8+'), '');
  assert.equal(safePhoto('photos/../secret.jpg'), '');
  assert.equal(safePhoto('photos/pasta.jpg'), 'photos/pasta.jpg');
  assert.equal(validDate('2026-02-30'), false);
  assert.equal(validDate('2028-02-29'), true);
  const state = validateState({ ...empty(), recipes: [{ id: 'r', ingredients: ['250 g de pasta'], steps: ['Hervir.'], videoUrl: 'https://youtube.com.evil.test/watch' }], tasks: [{ id: 't', title: 'Comprar', date: '2026-02-30', time: '99:00' }] });
  assert.equal(state.recipes[0].videoUrl, '');
  assert.equal(state.tasks[0].time, '09:00');
  assert.equal(validDate(state.tasks[0].date), true);
});

test('meal plans retain calendar dates and unsupported backup properties are discarded', () => {
  const state = validateState({ ...empty(), mealPlans: { '2026-09-14': { desayuno: 'r1', comida: 'r2', cena: '', unknown: 'hidden' }, '2026-02-30': { comida: 'r3' } }, settings: { theme: 'dark' } });
  assert.deepEqual(state.mealPlans, { '2026-09-14': { desayuno: 'r1', comida: 'r2', cena: '' } });
  assert.equal(state.settings.theme, 'dark');
});
