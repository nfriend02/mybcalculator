/**
 * Netlify Function — /api/weather
 * Proxies OpenWeatherMap so API keys stay server-side.
 */
exports.handler = async (event) => {
  const key = process.env.OPENWEATHER_API_KEY;
  const q = event.queryStringParameters?.q || 'Seoul';

  if (!key || key.startsWith('your_')) {
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: q,
        main: { temp: 22.5, humidity: 55 },
        weather: [{ description: '맑음 (데모)' }],
      }),
    };
  }

  const url =
    `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(q)}` +
    `&appid=${key}&units=metric&lang=kr`;

  const res = await fetch(url);
  const body = await res.text();
  return {
    statusCode: res.status,
    headers: { 'Content-Type': 'application/json' },
    body,
  };
};
