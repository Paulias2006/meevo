import { env } from '../config/env.js';

const AUTH_URL = 'https://client.cinetpay.com/v1/auth/login';
const CONTACT_URL = 'https://client.cinetpay.com/v1/transfer/contact';
const SEND_CONTACT_URL =
  'https://client.cinetpay.com/v1/transfer/money/send/contact';
const CHECK_TRANSFER_URL = 'https://client.cinetpay.com/v1/transfer/check/money';

let cachedToken = '';
let cachedTokenExpiresAt = 0;

export function isCinetpayPayoutConfigured() {
  return Boolean(env.CINETPAY_APIKEY && env.CINETPAY_PAYOUT_PASSWORD);
}

async function fetchJson(response) {
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      payload?.message?.toString() ||
        payload?.description?.toString() ||
        'CinetPay transfert impossible.',
    );
  }
  return payload;
}

export async function getCinetpayTransferToken({ force = false } = {}) {
  if (!isCinetpayPayoutConfigured()) {
    throw new Error('CinetPay payout n est pas configure.');
  }

  const now = Date.now();
  if (!force && cachedToken && cachedTokenExpiresAt > now + 10_000) {
    return cachedToken;
  }

  const params = new URLSearchParams({
    apikey: env.CINETPAY_APIKEY,
    password: env.CINETPAY_PAYOUT_PASSWORD,
  });

  const response = await fetch(`${AUTH_URL}?lang=fr`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'MeevoBackend/1.0',
    },
    body: params.toString(),
  });

  const payload = await fetchJson(response);

  if (payload.code !== 0) {
    throw new Error(payload.message?.toString() || 'Token CinetPay invalide.');
  }

  const token = payload.data?.token?.toString?.() || '';
  if (!token) {
    throw new Error('Token CinetPay introuvable.');
  }

  cachedToken = token;
  cachedTokenExpiresAt = now + 5 * 60 * 1000;
  return token;
}

export async function addCinetpayContact({
  token,
  prefix = env.CINETPAY_PAYOUT_PREFIX || '228',
  phone,
  name,
  surname = '',
  email = '',
}) {
  const response = await fetch(`${CONTACT_URL}?token=${encodeURIComponent(token)}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'MeevoBackend/1.0',
    },
    body: new URLSearchParams({
      data: JSON.stringify([
        {
          prefix,
          phone,
          name,
          surname,
          email,
        },
      ]),
    }).toString(),
  });

  const payload = await fetchJson(response);

  // code 0 = ok, mais si deja existant CinetPay peut renvoyer un code !=0
  // on ne bloque pas les transferts pour ce cas.
  return payload;
}

export async function sendCinetpayTransferToContact({
  token,
  amount,
  currency = env.CINETPAY_CURRENCY || 'XOF',
  description,
  contact,
  transactionId,
  notifyUrl = env.CINETPAY_PAYOUT_NOTIFY_URL || '',
}) {
  const response = await fetch(
    `${SEND_CONTACT_URL}?token=${encodeURIComponent(token)}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'MeevoBackend/1.0',
      },
      body: new URLSearchParams({
        data: JSON.stringify({
          transaction_id: transactionId,
          cpm_contact: contact,
          amount: Math.max(1, Math.round(Number(amount) || 0)),
          currency,
          description,
          notify_url: notifyUrl || undefined,
        }),
      }).toString(),
    },
  );

  const payload = await fetchJson(response);
  return payload;
}

export async function checkCinetpayTransferStatus({
  token,
  transactionId,
  currency = env.CINETPAY_CURRENCY || 'XOF',
}) {
  const url = new URL(CHECK_TRANSFER_URL);
  url.searchParams.set('token', token);
  url.searchParams.set('transaction_id', transactionId);
  url.searchParams.set('currency', currency);
  url.searchParams.set('lang', 'fr');

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'User-Agent': 'MeevoBackend/1.0',
    },
  });

  const payload = await fetchJson(response);
  return payload;
}

