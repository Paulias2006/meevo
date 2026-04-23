import { env } from '../config/env.js';

const CINETPAY_INIT_URL = 'https://api-checkout.cinetpay.com/v2/payment';
const CINETPAY_CHECK_URL = 'https://api-checkout.cinetpay.com/v2/payment/check';
const CINETPAY_TRANSFER_AUTH_URL = 'https://client.cinetpay.com/v1/auth/login';
const CINETPAY_TRANSFER_BALANCE_URL =
  'https://client.cinetpay.com/v1/transfer/check/balance';
const CINETPAY_TRANSFER_SEND_URL =
  'https://client.cinetpay.com/v1/transfer/money/send/contact';
const CINETPAY_TRANSFER_CHECK_URL =
  'https://client.cinetpay.com/v1/transfer/check/money';

export function isCinetpayConfigured() {
  return Boolean(env.CINETPAY_APIKEY && env.CINETPAY_SITE_ID);
}

export function isCinetpayPayoutConfigured() {
  return Boolean(
    env.CINETPAY_APIKEY &&
      env.CINETPAY_PAYOUT_PASSWORD &&
      (env.CINETPAY_PAYOUT_NOTIFY_URL || env.PUBLIC_BASE_URL),
  );
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

export function mapCinetpayTransferStatus(payload) {
  const item = Array.isArray(payload?.data) ? payload.data[0] : payload?.data;
  const treatmentStatus = String(
    item?.treatment_status || item?.treatmentStatus || '',
  ).toUpperCase();

  if (treatmentStatus === 'VAL') return 'paid';
  if (treatmentStatus === 'REJ' || treatmentStatus === 'REJECTED') {
    return 'failed';
  }
  if (treatmentStatus === 'ANN') return 'rejected';
  if (treatmentStatus) return 'processing';
  return 'pending';
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

function resolvePayoutNotifyUrl() {
  if (env.CINETPAY_PAYOUT_NOTIFY_URL) return env.CINETPAY_PAYOUT_NOTIFY_URL;
  if (env.PUBLIC_BASE_URL) {
    return `${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/api/bookings/finance/payout/notify`;
  }
  return '';
}

async function parseJsonResponse(response) {
  return response.json().catch(() => ({}));
}

async function generateCinetpayTransferToken() {
  if (!isCinetpayPayoutConfigured()) {
    throw new Error(
      'CinetPay payout n est pas configure. Ajoutez CINETPAY_PAYOUT_PASSWORD et une URL de notification.',
    );
  }

  const body = new URLSearchParams({
    apikey: env.CINETPAY_APIKEY,
    password: env.CINETPAY_PAYOUT_PASSWORD,
  });

  const response = await fetch(`${CINETPAY_TRANSFER_AUTH_URL}?lang=fr`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'MeevoBackend/1.0',
    },
    body,
  });

  const payload = await parseJsonResponse(response);
  if (!response.ok || Number(payload?.code) !== 0) {
    throw new Error(
      payload?.description?.toString() ||
        payload?.message?.toString() ||
        'Authentification payout CinetPay impossible.',
    );
  }

  const token = payload?.data?.token?.toString?.() || '';
  if (!token) {
    throw new Error('Token payout CinetPay introuvable.');
  }

  return token;
}

export async function checkCinetpayTransferBalance() {
  const token = await generateCinetpayTransferToken();
  const url = new URL(CINETPAY_TRANSFER_BALANCE_URL);
  url.searchParams.set('token', token);
  url.searchParams.set('lang', 'fr');

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'User-Agent': 'MeevoBackend/1.0',
    },
  });

  const payload = await parseJsonResponse(response);
  if (!response.ok || Number(payload?.code) !== 0) {
    throw new Error(
      payload?.description?.toString() ||
        payload?.message?.toString() ||
        'Lecture du solde payout CinetPay impossible.',
    );
  }

  return payload?.data ?? {};
}

export async function initiateCinetpayTransfer({
  clientTransferId,
  amount,
  phoneNumber,
  prefix = env.CINETPAY_PAYOUT_PREFIX || '228',
  paymentMethod = '',
}) {
  const token = await generateCinetpayTransferToken();
  const notifyUrl = resolvePayoutNotifyUrl();
  if (!notifyUrl) {
    throw new Error('URL de notification payout CinetPay manquante.');
  }

  let safeAmount = Math.max(5, Math.round(Number(amount) || 0));
  safeAmount = Math.floor(safeAmount / 5) * 5;
  if (safeAmount <= 0) {
    throw new Error('Montant de retrait invalide.');
  }

  const transferPayload = [
    {
      prefix: String(prefix || '228').replace(/\D/g, ''),
      phone: String(phoneNumber || '').replace(/\D/g, ''),
      amount: safeAmount,
      client_transaction_id: clientTransferId,
      notify_url: notifyUrl,
      ...(paymentMethod ? { payment_method: paymentMethod } : {}),
    },
  ];

  const body = new URLSearchParams({
    data: JSON.stringify(transferPayload),
  });

  const response = await fetch(`${CINETPAY_TRANSFER_SEND_URL}?token=${encodeURIComponent(token)}&lang=fr`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'MeevoBackend/1.0',
    },
    body,
  });

  const payload = await parseJsonResponse(response);
  if (!response.ok || Number(payload?.code) !== 0) {
    throw new Error(
      payload?.description?.toString() ||
        payload?.message?.toString() ||
        'Envoi du retrait CinetPay impossible.',
    );
  }

  const item = Array.isArray(payload?.data) ? payload.data[0] : payload?.data;
  return {
    raw: payload,
    item,
    internalStatus: mapCinetpayTransferStatus({ data: item }),
  };
}

export async function checkCinetpayTransferStatus({
  transactionId,
  clientTransferId,
  lot,
}) {
  const token = await generateCinetpayTransferToken();
  const url = new URL(CINETPAY_TRANSFER_CHECK_URL);
  url.searchParams.set('token', token);
  url.searchParams.set('lang', 'fr');
  if (transactionId) {
    url.searchParams.set('transaction_id', transactionId);
  }
  if (clientTransferId) {
    url.searchParams.set('client_transaction_id', clientTransferId);
  }
  if (lot) {
    url.searchParams.set('lot', lot);
  }

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'User-Agent': 'MeevoBackend/1.0',
    },
  });

  const payload = await parseJsonResponse(response);
  if (!response.ok || Number(payload?.code) !== 0) {
    throw new Error(
      payload?.description?.toString() ||
        payload?.message?.toString() ||
        'Verification du retrait CinetPay impossible.',
    );
  }

  return {
    ...payload,
    internalStatus: mapCinetpayTransferStatus(payload),
  };
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

  const payload = await parseJsonResponse(response);

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

  const payload = await parseJsonResponse(response);

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
