import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const source = readFileSync(new URL('../src/main.js', import.meta.url), 'utf8');
// Execute the production submit listener without starting the browser application.
// Keep both registration boundaries explicit so a refactor cannot silently skip it.
const registration = source.match(
  /app\.addEventListener\(\s*(['"])submit\1[\s\S]*?(?=app\.addEventListener\(\s*(['"])change\2)/,
)?.[0];
assert.ok(registration, 'The production submit listener must be available to this regression test.');

function harness() {
  let submitHandler, commits = 0, nextId = 0;
  const errors = [];
  const data = { products: [], shopping: [], recipes: [], favorites: [], tasks: [], mealPlans: {} };
  const ui = { modal: {} };
  runInNewContext(registration, {
    app: { addEventListener: (event, handler) => { assert.equal(event, 'submit'); submitHandler = handler; } },
    FormData: class {
      constructor(form) { this.fields = form.fields; }
      get(name) { return this.fields.get(name) ?? null; }
    },
    data, ui, imageDraft: '',
    productById: id => data.products.find(item => item.id === id),
    entryById: id => data.shopping.find(item => item.id === id),
    uuid: () => `fixture-${++nextId}`,
    localDate: () => '2026-09-14',
    validDate: value => /^\d{4}-\d{2}-\d{2}$/.test(value),
    isRecipeAllowed: () => true,
    closeModal: () => { ui.modal = null; },
    commit: () => { commits++; },
    formError: (_form, error) => { errors.push(error); },
    checkReminders: () => {},
  });
  return {
    data,
    async submit(formId, values) {
      ui.modal = {};
      const button = { disabled: false };
      const form = {
        fields: new Map(Object.entries(values)),
        // HTMLFormElement named-property access returns these controls, not the
        // form's id/name attributes. This was the cause of silently unsaved forms.
        id: { tagName: 'INPUT', name: 'id', value: values.id || '' },
        name: { tagName: 'INPUT', name: 'name', value: values.name || '' },
        getAttribute: attribute => attribute === 'id' ? formId : null,
        reportValidity: () => true,
        querySelector: () => button,
      };
      let prevented = false;
      const previousCommits = commits;
      await submitHandler({ target: form, preventDefault: () => { prevented = true; } });
      assert.equal(prevented, true);
      assert.deepEqual(errors, [], 'The submit handler must not report a hidden error.');
      assert.equal(commits, previousCommits + 1, `${formId} must persist instead of silently doing nothing.`);
      assert.equal(button.disabled, false, 'The submit button must become usable again.');
    },
  };
}

for (const fixture of [
  {
    form: 'product-form', collection: 'products', label: 'name',
    fields: { id: '', name: 'Pasta', description: 'Paquete de prueba', category: 'Comida', usualPrice: '20', contentValue: '250', contentUnit: 'g', stock: '2', lowAt: '1' },
    update: { name: 'Pasta integral', usualPrice: '22' },
  },
  {
    form: 'shopping-form', collection: 'shopping', label: 'name',
    fields: { id: '', name: 'Jabón', detail: 'Una pieza', kind: 'low', price: '25' },
    update: { name: 'Jabón de manos', kind: 'urgent' },
  },
  {
    form: 'recipe-form', collection: 'recipes', label: 'title',
    fields: { id: '', title: 'Pasta casera', description: 'Prueba', ingredients: '250 g de pasta\n1 L de agua', steps: 'Calienta el agua.\nCuece la pasta.', time: '15', servings: '2', cuisine: 'Casera', videoUrl: '' },
    update: { title: 'Mi pasta casera', servings: '3' },
  },
  {
    form: 'task-form', collection: 'tasks', label: 'title',
    fields: { id: '', title: 'Comprar la despensa', notes: 'Lista semanal', date: '2026-09-14', time: '18:00', priority: 'normal' },
    update: { title: 'Comprar y organizar la despensa', time: '19:00' },
  },
]) {
  test(`${fixture.form} saves and edits when input[name=id] shadows form.id`, async () => {
    const instance = harness();
    await instance.submit(fixture.form, fixture.fields);
    assert.equal(instance.data[fixture.collection].length, 1);
    const original = instance.data[fixture.collection][0];
    assert.equal(original[fixture.label], fixture.fields[fixture.label]);
    await instance.submit(fixture.form, { ...fixture.fields, ...fixture.update, id: original.id });
    assert.equal(instance.data[fixture.collection].length, 1, 'Editing must not create a duplicate.');
    assert.equal(instance.data[fixture.collection][0].id, original.id);
    assert.equal(instance.data[fixture.collection][0][fixture.label], fixture.update[fixture.label]);
  });
}

test('named controls do not shadow other form properties or methods used by handlers', () => {
  const controlNames = new Set();
  for (const match of source.matchAll(/<(?:input|select|textarea|button)\b[^>]*>/g)) {
    for (const attribute of match[0].matchAll(/\b(?:id|name)="([^"]+)"/g)) {
      controlNames.add(attribute[1]);
    }
  }
  assert.ok(controlNames.has('id') && controlNames.has('name'), 'The regression fixture reflects actual named controls.');
  for (const access of source.matchAll(/\bform(?:\.([A-Za-z_$][\w$]*)|\[\s*['"]([^'"]+)['"]\s*\])/g)) {
    const property = access[1] || access[2];
    assert.equal(controlNames.has(property), false, `form.${property} can be hidden by a named control; use an explicit attribute or selector.`);
  }
});
