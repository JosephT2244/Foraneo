import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateComparablePrice, evaluatePrice, getPriceTier } from '../src/price-rules.js';

test('el margen especial hasta $40 permite hasta 10% de aumento', function () {
  assert.equal(evaluatePrice(40, 44).decision, 'avoid');
  assert.equal(evaluatePrice(40, 43.99).decision, 'approved');
});

test('una oferta de 15% hasta $200 se marca como compra prioritaria', function () {
  assert.equal(evaluatePrice(200, 170).decision, 'deal');
  assert.equal(evaluatePrice(100, 85).decision, 'deal');
});

test('los márgenes por tramo se aplican correctamente', function () {
  assert.equal(evaluatePrice(100, 108).decision, 'avoid');
  assert.equal(evaluatePrice(500, 515).decision, 'avoid');
  assert.equal(evaluatePrice(1000, 1020).decision, 'avoid');
  assert.equal(evaluatePrice(2000, 2020).decision, 'avoid');
});

test('precios dentro del rango quedan autorizados', function () {
  assert.equal(evaluatePrice(500, 510).decision, 'approved');
  assert.equal(evaluatePrice(75, 80).decision, 'approved');
  assert.equal(getPriceTier(250).increasePercent, 3);
});

test('normaliza el precio cuando cambia el tamaño del empaque', function () {
  const result = evaluateComparablePrice({
    usualPrice: 20,
    usualContentValue: 250,
    usualContentUnit: 'g',
    proposedPrice: 40,
    proposedContentValue: 500,
    proposedContentUnit: 'g'
  });
  assert.equal(result.decision, 'approved');
  assert.equal(result.comparablePrice, 20);
});
