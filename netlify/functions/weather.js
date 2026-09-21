/**
 * Netlify Function — /api/weather
 * Proxies OpenWeatherMap so API keys stay server-side.
 */
const CITY_ALIASES = {
  요코하마: 'Yokohama',
  요꼬하마: 'Yokohama',
  서울: 'Seoul',
  부산: 'Busan',
  인천: 'Incheon',
  대구: 'Daegu',
  대전: 'Daejeon',
  광주: 'Gwangju',
  도쿄: 'Tokyo',
  오사카: 'Osaka',
  교토: 'Kyoto',
  나고야: 'Nagoya',
  베이징: 'Beijing',
  상하이: 'Shanghai',
  뉴욕: 'New York',
  런던: 'London',
  파리: 'Paris',
};

function resolveCity(q) {
  const raw = (q || 'Seoul').trim();
  if (!raw) return 'Seoul';
  return CITY_ALIASES[raw] || CITY_ALIASES[raw.replace(/\s+/g, '')] || raw;
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=120',
    },
    body: JSON.stringify(body),
  };
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET,OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
      body: '',
    };
  }

  const key = process.env.OPENWEATHER_API_KEY;
  const q = resolveCity(event.queryStringParameters?.q);

  if (!key || key.startsWith('your_') || key.trim() === '') {
    return json(200, {
      name: q,
      main: { temp: 22.5, humidity: 55 },
      weather: [{ description: '맑음 (데모 — OPENWEATHER_API_KEY 미설정)' }],
      demo: true,
    });
  }

  try {
    const url =
      `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(q)}` +
      `&appid=${key}&units=metric&lang=kr`;

    const res = await fetch(url);
    const text = await res.text();

    if (!res.ok) {
      let message = `OpenWeather ${res.status}`;
      try {
        const err = JSON.parse(text);
        if (err?.message) message = err.message;
      } catch (_) {
        /* keep status message */
      }
      return json(res.status === 404 ? 404 : 502, {
        error: true,
        message,
        query: q,
      });
    }

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=120',
      },
      body: text,
    };
  } catch (err) {
    return json(502, {
      error: true,
      message: String(err?.message || err),
      query: q,
    });
  }
};
