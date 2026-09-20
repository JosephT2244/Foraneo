import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';
import fixtures from './recipe-fixtures.json' with { type: 'json' };
import { getLocalRecipes, recommendLocalRecipes, normalizeIngredient, ingredientMatches, missingIngredients, isRecipeAllowed } from '../src/offline-recipes.js';

test('the shared offline catalog is complete, original, quantified and preference-compatible', () => {
  const web = readFileSync(new URL('../public/recipes/catalog.json', import.meta.url));
  const native = readFileSync(new URL('../foraneo_flutter/assets/recipes/catalog.json', import.meta.url));
  assert.deepEqual(web, native);
  const recipes = getLocalRecipes();
  assert.ok(recipes.length >= 5300);
  assert.ok(new Set(recipes.map(recipe => recipe.baseId)).size >= 90);
  assert.equal(new Set(recipes.map(recipe => recipe.id)).size, recipes.length);
  assert.equal(new Set(recipes.map(recipe => recipe.title)).size, recipes.length);
  assert.ok(gzipSync(web).length < 1000000, 'the expanded offline cookbook should compress efficiently');
  for (const recipe of recipes) {
    assert.ok(recipe.title && recipe.description && recipe.baseTitle, recipe.id);
    assert.ok(recipe.ingredients.length >= 4 && recipe.ingredients.every(ingredient => /^\d/.test(ingredient)), recipe.id);
    assert.equal(recipe.ingredients.length, recipe.ingredientKeys.length, recipe.id);
    assert.ok(recipe.steps.length >= 7 && recipe.steps.every(step => step.length > 40), recipe.id);
    assert.ok(recipe.steps.some(step => /\d.*(?:minuto|hora)/.test(step)), recipe.id);
    assert.equal(recipe.servings, 2);
    assert.ok(recipe.time > 0 && recipe.minutes);
    assert.ok(isRecipeAllowed(recipe), recipe.id);
    assert.ok(existsSync(fileURLToPath(new URL(`../public/${recipe.image}`, import.meta.url))), recipe.id);
    assert.ok(recipe.source.startsWith('Recetario original Foráneo'));
    assert.equal(recipe.videoUrl, '', 'do not invent a verified video');
  }
});

test('ingredient normalisation and matching follow shared JS/Dart fixtures', () => {
  for (const [input, expected] of fixtures.normalization) assert.equal(normalizeIngredient(input), expected, input);
  for (const [a, b, expected] of fixtures.matching) assert.equal(ingredientMatches(a, b), expected, `${a} / ${b}`);
});

test('restrictions inspect ingredients and preparation, not just recipe titles', () => {
  for (const [recipe, expected] of fixtures.restrictions) assert.equal(isRecipeAllowed(recipe), expected, recipe.title);
});

test('recommendation ranking is deterministic, relevant and diverse', () => {
  for (const fixture of fixtures.queries) assert.deepEqual(recommendLocalRecipes(fixture).map(recipe => recipe.id), fixture.ids, fixture.query);
  const first = recommendLocalRecipes({ query: 'pasta', limit: 8 });
  const next = recommendLocalRecipes({ query: 'pasta', limit: 8, offset: 8 });
  assert.equal(new Set([...first, ...next].map(recipe => recipe.id)).size, 16);
  assert.ok(new Set(first.map(recipe => recipe.baseId)).size >= 4);
  assert.ok(first.every(recipe => recipe.ingredientKeys.includes('pasta')));
  assert.deepEqual(recommendLocalRecipes({ limit: 0 }), []);
  assert.ok(recommendLocalRecipes({ exclude: first.map(recipe => recipe.id), limit: 8 }).every(recipe => !first.includes(recipe)));
  const best = recommendLocalRecipes({ query: 'pasta', pantry: ['pasta', 'tofu', 'brócoli', 'tomate', 'ajo', 'orégano', 'cebolla', 'sal', 'aceite de oliva'], limit: 1 })[0];
  assert.equal(best.id, 'local-pasta-tomate-tofu-brocoli');
});

test('missing ingredients ignore water, zero-stock and nonfood; preserve complete quantity labels', () => {
  const recipe = getLocalRecipes()[0];
  const all = recipe.ingredientKeys.filter(key => key !== 'agua');
  assert.deepEqual(missingIngredients(recipe, all), []);
  const missing = missingIngredients(recipe, [{ name: 'pasta', stock: 0, category: 'comida' }, { name: 'pollo', stock: 1, category: 'higiene' }]);
  assert.ok(missing.includes(recipe.ingredients[0]));
  assert.ok(missing.some(ingredient => ingredient.includes('pollo')));
  assert.ok(!missing.some(ingredient => /^\d+ ml de agua/.test(ingredient)));
  assert.equal(ingredientMatches('pasta', { name: 'Pasta fusilli', stock: 1 }), true);
});

test('explicit ingredient exclusions never promote the excluded ingredient', () => {
  for (const query of ['sin pollo', 'sin pollo ni tofu', 'pasta sin pollo, tofu', 'sin pollo con pasta']) {
    const recipes = recommendLocalRecipes({ query, limit: 200 });
    assert.ok(recipes.length > 0, query);
    assert.ok(recipes.every(recipe => !recipe.ingredientKeys.includes('pollo')), query);
    if (query.includes('tofu')) assert.ok(recipes.every(recipe => !recipe.ingredientKeys.includes('tofu')), query);
  }
  const dairy = recommendLocalRecipes({ query: 'pasta sin yogur natural', limit: 200 });
  assert.ok(dairy.length > 0);
  assert.ok(dairy.every(recipe => !recipe.ingredientKeys.includes('yogur natural')));
});

test('hard-boiled salads prepare vegetables before cooking and drain after both are cooked', () => {
  const salads = getLocalRecipes().filter(recipe => recipe.baseId === 'ensalada-huevo-duro');
  assert.equal(salads.length, 10);
  for (const recipe of salads) {
    const begin = recipe.steps.findIndex(step => step.includes('Cocina 4 minutos sin escurrir'));
    const complete = recipe.steps.findIndex(step => step.includes('Con la papa todavía hirviendo'));
    assert.ok(begin > 0 && complete === begin + 1, recipe.id);
    assert.ok(recipe.steps[complete].includes('Solo entonces escurre'), recipe.id);
    assert.ok(!recipe.steps.slice(0, complete).some(step => /Escurre y deja/.test(step)), recipe.id);
  }
});
