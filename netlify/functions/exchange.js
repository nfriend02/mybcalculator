/**
 * Netlify Function — /api/exchange
 *
 * Priority:
 *  1) Current / live mid-market rate
 *  2) Previous close (last business day historical)
 *  3) Built-in reference demo rates
 *
 * Response:
 *  { base:'KRW', rates:{USD:…}, source:'live'|'previous_close'|'demo',
 *    asOf:'YYYY-MM-DD', label:'오늘 환율'|'직전 종가'|'참고 환율' }
 * rates[CODE] = KRW per 1 unit of CODE
 */
const CODES = [
  'USD', 'EUR', 'JPY', 'CNY', 'GBP', 'SGD',
  'TWD', 'CAD', 'AUD', 'FRF', 'KRW',
];

const DEMO = {
  USD: 1350,
  EUR: 1460,
  JPY: 9.1,
  CNY: 185,
  GBP: 1710,
  SGD: 1020,
  TWD: 42,
  CAD: 980,
  AUD: 880,
  FRF: 222.57, // ≈ EUR / 6.55957 (legacy French franc)
  KRW: 1,
};

const FRF_PER_EUR = 6.55957;

function json(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=300',
    },
    body: JSON.stringify(body),
  };
}

function todayUtc() {
  return new Date().toISOString().slice(0, 10);
}

function shiftDate(iso, days) {
  const d = new Date(`${iso}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** Skip Sat/Sun — walk back to last weekday. */
function previousBusinessDay(fromIso = todayUtc()) {
  let d = shiftDate(fromIso, -1);
  for (let i = 0; i < 7; i++) {
    const wd = new Date(`${d}T12:00:00Z`).getUTCDay(); // 0=Sun..6=Sat
    if (wd !== 0 && wd !== 6) return d;
    d = shiftDate(d, -1);
  }
  return d;
}

function ratesFromUsdTable(cr) {
  const usdToKrw = Number(cr.KRW);
  if (!usdToKrw || Number.isNaN(usdToKrw)) return null;
  const rates = {};
  for (const code of CODES) {
    if (code === 'KRW') {
      rates.KRW = 1;
      continue;
    }
    if (code === 'USD') {
      rates.USD = usdToKrw;
      continue;
    }
    if (code === 'FRF') continue; // derived from EUR below
    const usdToCode = Number(cr[code]);
    if (!usdToCode || Number.isNaN(usdToCode)) {
      rates[code] = DEMO[code];
      continue;
    }
    rates[code] = usdToKrw / usdToCode;
  }
  const eur = rates.EUR || DEMO.EUR;
  rates.FRF = Number(cr.FRF) > 0 ? usdToKrw / Number(cr.FRF) : eur / FRF_PER_EUR;
  return rates;
}

async function fetchLiveWithKey(key) {
  const url = `https://v6.exchangerate-api.com/v6/${encodeURIComponent(key)}/latest/USD`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`live-key ${res.status}`);
  const data = await res.json();
  const rates = ratesFromUsdTable(data.conversion_rates || {});
  if (!rates) throw new Error('live-key missing KRW');
  return {
    rates,
    source: 'live',
    label: '오늘 환율',
    asOf: todayUtc(),
    provider: 'exchangerate-api',
  };
}

async function fetchLiveOpen() {
  // Free, no-key current rates (ExchangeRate-API open endpoint).
  const url = 'https://open.er-api.com/v6/latest/USD';
  const res = await fetch(url);
  if (!res.ok) throw new Error(`live-open ${res.status}`);
  const data = await res.json();
  if (data.result && data.result !== 'success') {
    throw new Error(`live-open ${data.result}`);
  }
  const rates = ratesFromUsdTable(data.rates || data.conversion_rates || {});
  if (!rates) throw new Error('live-open missing KRW');
  const asOf = data.time_last_update_utc
    ? String(data.time_last_update_utc).slice(0, 16)
    : todayUtc();
  return {
    rates,
    source: 'live',
    label: '오늘 환율',
    asOf,
    provider: 'open.er-api.com',
  };
}

async function fetchPreviousCloseWithKey(key) {
  const date = previousBusinessDay();
  const [y, m, d] = date.split('-');
  const url =
    `https://v6.exchangerate-api.com/v6/${encodeURIComponent(key)}` +
    `/history/USD/${y}/${Number(m)}/${Number(d)}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`close-key ${res.status}`);
  const data = await res.json();
  const rates = ratesFromUsdTable(data.conversion_rates || {});
  if (!rates) throw new Error('close-key missing KRW');
  return {
    rates,
    source: 'previous_close',
    label: '직전 종가',
    asOf: date,
    provider: 'exchangerate-api-history',
  };
}

async function fetchPreviousCloseOpen() {
  // open.er-api has no public history — approximate "previous close"
  // by accepting live payload but tagging as previous_close only when
  // live fetch already failed. Prefer frankfurter historical if reachable.
  const date = previousBusinessDay();
  const urls = [
    `https://api.frankfurter.app/${date}?from=USD&to=${CODES.filter((c) => c !== 'USD' && c !== 'KRW').join(',')},KRW`,
    `https://api.frankfurter.dev/v1/${date}?base=USD&symbols=${CODES.filter((c) => c !== 'USD').join(',')}`,
  ];
  let lastErr = 'close-open failed';
  for (const url of urls) {
    try {
      const res = await fetch(url, {
        headers: { Accept: 'application/json', 'User-Agent': 'mybcalculator/1.0' },
      });
      if (!res.ok) {
        lastErr = `close-open ${res.status}`;
        continue;
      }
      const data = await res.json();
      const table = data.rates || {};
      // Frankfurter: rates are "1 USD = X CODE"
      const cr = { ...table, USD: 1 };
      if (!cr.KRW && table.KRW) cr.KRW = table.KRW;
      const rates = ratesFromUsdTable(cr);
      if (!rates) continue;
      return {
        rates,
        source: 'previous_close',
        label: '직전 종가',
        asOf: data.date || date,
        provider: 'frankfurter',
      };
    } catch (e) {
      lastErr = String(e?.message || e);
    }
  }
  throw new Error(lastErr);
}

exports.handler = async () => {
  const key = (process.env.EXCHANGE_RATE_API_KEY || '').trim().replace(/^['"]|['"]$/g, '');
  const errors = [];

  // 1) Current / live
  if (key && !key.startsWith('your_')) {
    try {
      return json(200, await fetchLiveWithKey(key));
    } catch (e) {
      errors.push(String(e?.message || e));
    }
  }
  try {
    return json(200, await fetchLiveOpen());
  } catch (e) {
    errors.push(String(e?.message || e));
  }

  // 2) Previous close
  if (key && !key.startsWith('your_')) {
    try {
      return json(200, await fetchPreviousCloseWithKey(key));
    } catch (e) {
      errors.push(String(e?.message || e));
    }
  }
  try {
    return json(200, await fetchPreviousCloseOpen());
  } catch (e) {
    errors.push(String(e?.message || e));
  }

  // 3) Demo reference
  return json(200, {
    base: 'KRW',
    rates: DEMO,
    source: 'demo',
    label: '참고 환율',
    asOf: todayUtc(),
    provider: 'demo',
    error: errors.join(' | '),
  });
};
