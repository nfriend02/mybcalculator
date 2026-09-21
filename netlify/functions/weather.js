/**
 * Netlify Function — /api/weather
 * Proxies OpenWeatherMap so API keys stay server-side.
 */
const CITY_ALIASES = {
  // Korea
  서울: 'Seoul',
  부산: 'Busan',
  인천: 'Incheon',
  대구: 'Daegu',
  대전: 'Daejeon',
  광주: 'Gwangju',
  울산: 'Ulsan',
  제주: 'Jeju',
  // Japan
  도쿄: 'Tokyo',
  오사카: 'Osaka',
  교토: 'Kyoto',
  나고야: 'Nagoya',
  요코하마: 'Yokohama',
  요꼬하마: 'Yokohama',
  후쿠오카: 'Fukuoka',
  삿포로: 'Sapporo',
  // China / TW / HK
  베이징: 'Beijing',
  북경: 'Beijing',
  상하이: 'Shanghai',
  상해: 'Shanghai',
  광저우: 'Guangzhou',
  선전: 'Shenzhen',
  홍콩: 'Hong Kong',
  타이베이: 'Taipei',
  대만: 'Taipei',
  // SE Asia
  싱가포르: 'Singapore',
  방콕: 'Bangkok',
  호치민: 'Ho Chi Minh City',
  하노이: 'Hanoi',
  자카르타: 'Jakarta',
  쿠알라룸푸르: 'Kuala Lumpur',
  마닐라: 'Manila',
  // Americas
  뉴욕: 'New York',
  로스앤젤레스: 'Los Angeles',
  엘에이: 'Los Angeles',
  샌프란시스코: 'San Francisco',
  시카고: 'Chicago',
  시애틀: 'Seattle',
  토론토: 'Toronto',
  밴쿠버: 'Vancouver',
  멕시코시티: 'Mexico City',
  // Europe
  런던: 'London',
  파리: 'Paris',
  베를린: 'Berlin',
  로마: 'Rome',
  마드리드: 'Madrid',
  바르셀로나: 'Barcelona',
  암스테르담: 'Amsterdam',
  취리히: 'Zurich',
  빈시: 'Vienna',
  비엔나: 'Vienna',
  모스크바: 'Moscow',
  // Oceania / Mid-East / Africa / India
  시드니: 'Sydney',
  멜버른: 'Melbourne',
  오클랜드: 'Auckland',
  두바이: 'Dubai',
  아부다비: 'Abu Dhabi',
  카이로: 'Cairo',
  케이프타운: 'Cape Town',
  뭄바이: 'Mumbai',
  델리: 'New Delhi',
  뉴델리: 'New Delhi',
  방갈로르: 'Bengaluru',
};

function resolveCity(q) {
  const raw = (q || 'Seoul').trim();
  if (!raw) return 'Seoul';
  const compact = raw.replace(/\s+/g, '');
  return CITY_ALIASES[raw] || CITY_ALIASES[compact] || raw;
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
