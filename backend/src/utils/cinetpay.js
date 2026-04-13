import { env } from '../config/env.js';

const CINETPAY_INIT_URL = 'https://api-checkout.cinetpay.com/v2/payment';
const CINETPAY_CHECK_URL = 'https://api-checkout.cinetpay.com/v2/payment/check';

export function isCinetpayConfigured() {
  return Boolean(env.CINETPAY_APIKEY && env.CINETPAY_SITE_ID);
}

export function mapCinetpayStatus(payload) {
  const data = payload?.data ?? {};
  const status = String(data?.status ?? '').toUpperCase();

  if (status === 'ACCEPTED') return 'success';
  if (status === 'REFUSED') return 'failed';
  if (status === 'CANCELLED') return 'cancelled';

  // CinetPay peut renvoyer des codes "PENDING" selon le canal/operateur.
  if (status === 'PENDING' || status === 'WAITING' || status === 'PROCESSING') {
    return 'processing';
  }

  // Par defaut on garde "processing" plutot que d echouer brutalement.
  return 'processing';
}

function resolveNotifyUrl() {
  if (env.CINETPAY_NOTIFY_URL) return env.CINETPAY_NOTIFY_URL;
  if (env.PUBLIC_BASE_URL) {
    return `${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/api/cinetpay/notify`;
  }
  return '';
}

function resolveReturnUrl() {
  if (env.CINETPAY_RETURN_URL) return env.CINETPAY_RETURN_URL;
  if (env.PUBLIC_BASE_URL) return env.PUBLIC_BASE_URL;
  return '';
}

export async function initiateCinetpayPayment({
  transactionId,
  amount,
  description,
  customerName = '',
  customerEmail = '',
  customerPhoneNumber = '',
  channels = env.CINETPAY_CHANNELS || 'MOBILE_MONEY',
  currency = env.CINETPAY_CURRENCY || 'XOF',
  lang = env.CINETPAY_LANG || 'fr',
  metadata = '',
}) {
  if (!isCinetpayConfigured()) {
    throw new Error('CinetPay n est pas configure.');
  }

  const notifyUrl = resolveNotifyUrl();
  const returnUrl = resolveReturnUrl();

  if (!notifyUrl || !returnUrl) {
    throw new Error(
      'CinetPay: configurez CINETPAY_NOTIFY_URL et CINETPAY_RETURN_URL (ou PUBLIC_BASE_URL).',
    );
  }

  let safeAmount = Math.max(1, Math.round(Number(amount) || 0));
  if (String(currency).toUpperCase() === 'XOF') {
    // CinetPay impose un montant multiple de 5 pour le mobile money XOF.
    safeAmount = Math.ceil(safeAmount / 5) * 5;
  }

  const response = await fetch(CINETPAY_INIT_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'MeevoBackend/1.0',
    },
    body: JSON.stringify({
      apikey: env.CINETPAY_APIKEY,
      site_id: env.CINETPAY_SITE_ID,
      transaction_id: transactionId,
      amount: safeAmount,
      currency,
      description,
      channels,
      notify_url: notifyUrl,
      return_url: returnUrl,
      customer_name: customerName || '',
      customer_surname: '',
      customer_email: customerEmail || '',
      customer_phone_number: customerPhoneNumber || '',
      lock_phone_number: true,
      lang,
      metadata,
    }),
  });

  const payload = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(
      payload?.description?.toString() ||
        payload?.message?.toString() ||
        'Initialisation CinetPay impossible.',
    );
  }

  if (String(payload.code) !== '201') {
    throw new Error(
      payload?.description?.toString() ||
        payload?.message?.toString() ||
        `Initialisation CinetPay refusee (code ${payload.code}).`,
    );
  }

  const paymentToken = payload?.data?.payment_token?.toString?.() || '';
  const paymentUrl = payload?.data?.payment_url?.toString?.() || '';

  if (!paymentUrl) {
    throw new Error('CinetPay: URL de paiement introuvable.');
  }

  return {
    paymentToken,
    paymentUrl,
    raw: payload,
  };
}

export async function checkCinetpayPaymentStatus(transactionId) {
  if (!isCinetpayConfigured()) {
    throw new Error('CinetPay n est pas configure.');
  }

  const response = await fetch(CINETPAY_CHECK_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'MeevoBackend/1.0',
    },
    body: JSON.stringify({
      apikey: env.CINETPAY_APIKEY,
      site_id: env.CINETPAY_SITE_ID,
      transaction_id: transactionId,
    }),
  });

  const payload = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(
      payload?.description?.toString() ||
        payload?.message?.toString() ||
        'Verification CinetPay impossible.',
    );
  }

  return {
    ...payload,
    internalStatus: mapCinetpayStatus(payload),
  };
}
