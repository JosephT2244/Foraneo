export const PRICE_TIERS = [
  {
    maxPrice: 40,
    discountPercent: 15,
    increasePercent: 10,
    label: 'Hasta $40'
  },
  {
    maxPrice: 100,
    discountPercent: 15,
    increasePercent: 8,
    label: 'De $41 a $100'
  },
  {
    maxPrice: 200,
    discountPercent: 15,
    increasePercent: 4,
    label: 'De $101 a $200'
  },
  {
    maxPrice: 500,
    discountPercent: 10,
    increasePercent: 3,
    label: 'De $201 a $500'
  },
  {
    maxPrice: 1000,
    discountPercent: 10,
    increasePercent: 2,
    label: 'De $501 a $1,000'
  },
  {
    maxPrice: Infinity,
    discountPercent: 10,
    increasePercent: 1,
    label: 'Más de $1,000'
  }
];

export function getPriceTier(usualPrice) {
  const value = Number(usualPrice);
  if (!Number.isFinite(value) || value <= 0) return PRICE_TIERS[0];
  return PRICE_TIERS.find(function (tier) {
    return value <= tier.maxPrice;
  }) || PRICE_TIERS[PRICE_TIERS.length - 1];
}

export function evaluatePrice(usualPrice, proposedPrice) {
  const usual = Number(usualPrice);
  const proposed = Number(proposedPrice);

  if (!Number.isFinite(usual) || usual <= 0 || !Number.isFinite(proposed) || proposed < 0) {
    return {
      decision: 'needs-reference',
      label: 'Guarda un precio usual',
      message: 'Necesitamos un precio usual válido para poder comparar.',
      changePercent: null,
      tier: getPriceTier(usual)
    };
  }

  const tier = getPriceTier(usual);
  const changePercent = ((proposed - usual) / usual) * 100;

  if (changePercent <= -tier.discountPercent) {
    return {
      decision: 'deal',
      label: '¡Cómpralo!',
      message: 'Está ' + Math.abs(changePercent).toFixed(1) + '% más barato que lo usual.',
      changePercent: changePercent,
      tier: tier
    };
  }

  if (changePercent >= tier.increasePercent) {
    return {
      decision: 'avoid',
      label: 'Mejor no lo compres',
      message: 'Está ' + changePercent.toFixed(1) + '% más caro que lo usual.',
      changePercent: changePercent,
      tier: tier
    };
  }

  return {
    decision: 'approved',
    label: 'Compra autorizada',
    message: 'El precio está dentro de tu margen saludable.',
    changePercent: changePercent,
    tier: tier
  };
}

function contentDimension(unit) {
  const normalized = String(unit || '').toLowerCase().trim();
  if (normalized === 'g' || normalized === 'kg') return 'mass';
  if (normalized === 'ml' || normalized === 'l') return 'volume';
  return normalized || 'unit';
}

function normalizedContent(value, unit) {
  const amount = Number(value);
  const normalizedUnit = String(unit || '').toLowerCase().trim();
  if (!Number.isFinite(amount) || amount <= 0) return null;
  if (normalizedUnit === 'kg') return amount * 1000;
  if (normalizedUnit === 'l') return amount * 1000;
  return amount;
}

export function evaluateComparablePrice(options) {
  const usualContent = normalizedContent(options.usualContentValue, options.usualContentUnit);
  const proposedContent = normalizedContent(options.proposedContentValue, options.proposedContentUnit);
  const sameDimension = contentDimension(options.usualContentUnit) === contentDimension(options.proposedContentUnit);

  if (!usualContent || !proposedContent || !sameDimension) {
    return {
      decision: 'needs-content',
      label: 'Revisa el contenido',
      message: 'El contenido nuevo no es comparable con el empaque habitual.',
      changePercent: null,
      tier: getPriceTier(options.usualPrice),
      comparablePrice: null
    };
  }

  const comparablePrice = Number(options.proposedPrice) * usualContent / proposedContent;
  const result = evaluatePrice(options.usualPrice, comparablePrice);
  return Object.assign({}, result, { comparablePrice: comparablePrice });
}
