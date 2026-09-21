/**
 * Netlify Function — /api/exchange
 * Live FX via ExchangeRate-API; falls back to demo rates if key missing/fails.
 * Response shape: { base: 'KRW', rates: { USD, EUR, ... } }  // units per 1 KRW inverted → amount in KRW per 1 unit
 * rates[CODE] = KRW per 1 unit of CODE (same as app CurrencyService).
 */
exports.handler = async () => {
  const demo = {
    USD: 1350,
    EUR: 1460,
    JPY: 9.1,
    CNY: 185,
    GBP: 1710,
    KRW: 1,
  };

  const key = process.env.EXCHANGE_RATE_API_KEY;
  if (!key || key.startsWith('your_')) {
    return json(200, { base: 'KRW', rates: demo, source: 'demo' });
  }

  try {
    // exchangerate-api.com v6 — conversion_rates are "1 USD = X CODE"
    const url = `https://v6.exchangerate-api.com/v6/${key}/latest/USD`;
    const res = await fetch(url);
    if (!res.ok) {
      return json(200, { base: 'KRW', rates: demo, source: 'demo', error: `upstream ${res.status}` });
    }
    const data = await res.json();
    const cr = data.conversion_rates || {};
    const usdToKrw = Number(cr.KRW);
    if (!usdToKrw || Number.isNaN(usdToKrw)) {
      return json(200, { base: 'KRW', rates: demo, source: 'demo', error: 'missing KRW' });
    }

    const codes = ['USD', 'EUR', 'JPY', 'CNY', 'GBP', 'KRW'];
    const rates = {};
    for (const code of codes) {
      if (code === 'KRW') {
        rates.KRW = 1;
        continue;
      }
      if (code === 'USD') {
        rates.USD = usdToKrw;
        continue;
      }
      const usdToCode = Number(cr[code]);
      if (!usdToCode || Number.isNaN(usdToCode)) {
        rates[code] = demo[code];
        continue;
      }
      // KRW per 1 CODE = (KRW per 1 USD) / (CODE per 1 USD)
      rates[code] = usdToKrw / usdToCode;
    }

    return json(200, { base: 'KRW', rates, source: 'live' });
  } catch (err) {
    return json(200, {
      base: 'KRW',
      rates: demo,
      source: 'demo',
      error: String(err?.message || err),
    });
  }
};

function json(statusCode, body) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
}
