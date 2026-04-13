export const SUBSCRIPTION_ALERT_DAYS = 7;
export const SUBSCRIPTION_GRACE_DAYS = 7;

function toDayStart(value) {
  return new Date(value.getFullYear(), value.getMonth(), value.getDate());
}

export function getPartnerSubscriptionVisibility(user) {
  if (!user) {
    return {
      isActive: false,
      inGracePeriod: false,
      isVisiblePublicly: false,
      daysUntilExpiry: null,
      daysUntilGraceEnd: null,
      expiresAt: null,
      graceEndsAt: null,
      state: 'inactive',
    };
  }

  if (user.role === 'admin') {
    return {
      isActive: true,
      inGracePeriod: false,
      isVisiblePublicly: true,
      daysUntilExpiry: null,
      daysUntilGraceEnd: null,
      expiresAt: null,
      graceEndsAt: null,
      state: 'active',
    };
  }

  const subscription = user.subscription;
  if (!subscription?.endsAt) {
    return {
      isActive: false,
      inGracePeriod: false,
      isVisiblePublicly: false,
      daysUntilExpiry: null,
      daysUntilGraceEnd: null,
      expiresAt: null,
      graceEndsAt: null,
      state: subscription?.status === 'pending' ? 'pending' : 'inactive',
    };
  }

  const now = toDayStart(new Date());
  const expiresAt = toDayStart(new Date(subscription.endsAt));
  const daysUntilExpiry = Math.floor(
    (expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
  );

  if (daysUntilExpiry >= 0) {
    return {
      isActive: true,
      inGracePeriod: false,
      isVisiblePublicly: true,
      daysUntilExpiry,
      daysUntilGraceEnd: SUBSCRIPTION_GRACE_DAYS,
      expiresAt,
      graceEndsAt: new Date(
        expiresAt.getTime() + SUBSCRIPTION_GRACE_DAYS * 24 * 60 * 60 * 1000,
      ),
      state: daysUntilExpiry <= SUBSCRIPTION_ALERT_DAYS ? 'expiring_soon' : 'active',
    };
  }

  const graceEndsAt = new Date(
    expiresAt.getTime() + SUBSCRIPTION_GRACE_DAYS * 24 * 60 * 60 * 1000,
  );
  const daysUntilGraceEnd = Math.floor(
    (graceEndsAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
  );

  if (daysUntilGraceEnd >= 0) {
    return {
      isActive: false,
      inGracePeriod: true,
      isVisiblePublicly: true,
      daysUntilExpiry,
      daysUntilGraceEnd,
      expiresAt,
      graceEndsAt,
      state: 'grace',
    };
  }

  return {
    isActive: false,
    inGracePeriod: false,
    isVisiblePublicly: false,
    daysUntilExpiry,
    daysUntilGraceEnd,
    expiresAt,
    graceEndsAt,
    state: subscription?.status === 'pending' ? 'pending' : 'expired',
  };
}

export function isPartnerVisiblePublicly(user) {
  return getPartnerSubscriptionVisibility(user).isVisiblePublicly;
}
