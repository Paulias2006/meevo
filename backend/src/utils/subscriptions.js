import { env } from '../config/env.js';

export const paymentNetworkOptions = [
  {
    code: 'MOOV',
    label: 'Moov Money',
    paymentMethodLabel: 'Flooz',
  },
  {
    code: 'TOGOCEL',
    label: 'Yas TMoney',
    paymentMethodLabel: 'TMoney',
  },
];

export function computeSubscriptionQuote(rawMonths) {
  const safeMonths = Math.max(
    1,
    Math.min(env.PARTNER_MAX_SUBSCRIPTION_MONTHS, Number(rawMonths) || 1),
  );
  const monthlyPrice = env.PARTNER_MONTHLY_PRICE;
  const grossAmount = monthlyPrice * safeMonths;

  let discountRate = 0;
  if (safeMonths >= 12) {
    discountRate = 0.1;
  } else if (safeMonths >= 6) {
    discountRate = 0.05;
  } else if (safeMonths >= 3) {
    discountRate = 0.02;
  }

  const discountAmount = Math.round(grossAmount * discountRate);
  const totalAmount = grossAmount - discountAmount;

  return {
    months: safeMonths,
    monthlyPrice,
    grossAmount,
    discountRate,
    discountAmount,
    totalAmount,
    cycle:
      safeMonths === 1
        ? 'monthly'
        : safeMonths === 12
          ? 'annual'
          : 'custom',
  };
}

export function buildSubscriptionPresets() {
  return [
    {
      code: 'monthly',
      title: 'Mensuel',
      subtitle: 'Entree rapide dans le dashboard',
      badge: '50 000 FCFA / mois',
      ...computeSubscriptionQuote(1),
    },
    {
      code: 'semiannual',
      title: '6 mois',
      subtitle: 'Economisez sur une vraie presence continue',
      badge: 'Remise 5%',
      ...computeSubscriptionQuote(6),
    },
    {
      code: 'annual',
      title: 'Annuel',
      subtitle: 'Le meilleur prix pour un partenaire etabli',
      badge: 'Remise 10%',
      ...computeSubscriptionQuote(12),
    },
  ];
}

export function addMonths(date, months) {
  const next = new Date(date);
  next.setMonth(next.getMonth() + months);
  return next;
}

export function hasActiveSubscription(subscription) {
  if (!subscription || subscription.status !== 'active' || !subscription.endsAt) {
    return false;
  }

  return new Date(subscription.endsAt).getTime() >= Date.now();
}

export function buildPartnerModules(partnerType = '') {
  const value = partnerType.toLowerCase();
  const modules = [];
  if (value.includes('salle') || value.includes('hotel') || value.includes('lieu')) {
    modules.push('venues');
  }
  if (value.includes('presta')) {
    modules.push('providers');
  }
  return modules.length > 0 ? modules : ['venues'];
}

export function createSubscriptionIdentifier(userId) {
  const stamp = Date.now();
  const suffix = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `MEEVO-SUB-${userId.toString().slice(-6).toUpperCase()}-${stamp}-${suffix}`;
}
