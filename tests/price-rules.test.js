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

test('los límites inclusivos no cambian por redondeo binario de precios decimales', function () {
  for (const [usual, proposed] of [[3.4, 3.74], [75.25, 81.27], [100.25, 104.26], [201, 207.03], [500.5, 510.51], [1001, 1011.01]]) {
    assert.equal(evaluatePrice(usual, proposed).decision, 'avoid', `${usual} → ${proposed}`);
    assert.equal(evaluatePrice(usual, proposed - .01).decision, 'approved');
  }
  for (const [usual, proposed] of [[3.4, 2.89], [75.2, 63.92], [100.2, 85.17], [201.1, 180.99], [500.5, 450.45], [1001.1, 900.99]]) {
    assert.equal(evaluatePrice(usual, proposed).decision, 'deal', `${usual} → ${proposed}`);
    assert.equal(evaluatePrice(usual, proposed + .01).decision, 'approved');
  }
  // A genuinely different value must not be rounded into an offer or rejection.
  assert.equal(evaluatePrice(75.25, 81.27 - .000001).decision, 'approved');
  assert.equal(evaluatePrice(3.4, 2.89 + .000001).decision, 'approved');
});

test('el límite decimal se conserva al comparar tamaños equivalentes', function () {
  assert.equal(evaluateComparablePrice({
    usualPrice: 75.25, usualContentValue: 250, usualContentUnit: 'g',
    proposedPrice: 162.54, proposedContentValue: .5, proposedContentUnit: 'kg'
  }).decision, 'avoid');
});

test('rechaza contenidos no positivos, no finitos y unidades incompatibles', function () {
  const options = {
    usualPrice: 20, usualContentValue: 250, usualContentUnit: 'g',
    proposedPrice: 40, proposedContentValue: .5, proposedContentUnit: 'kg'
  };
  for (const value of [0, -1, NaN, Infinity]) {
    assert.equal(evaluateComparablePrice({...options, usualContentValue: value}).decision, 'needs-content');
    assert.equal(evaluateComparablePrice({...options, proposedContentValue: value}).decision, 'needs-content');
  }
  for (const unit of ['ml', 'L', 'piezas', 'rollos', '']) {
    assert.equal(evaluateComparablePrice({...options, proposedContentUnit: unit}).decision, 'needs-content');
  }
  for (const value of [-1, NaN, Infinity]) {
    assert.equal(evaluateComparablePrice({...options, proposedPrice: value}).decision, 'needs-reference');
  }
});
