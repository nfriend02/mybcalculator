/**
 * Netlify Function — /api/calculate
 * Proxies Gemini (text + Vision/PDF inline) so the API key stays server-side.
 */
function json(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-store',
    },
    body: JSON.stringify(body),
  };
}

function cleanKey(raw) {
  if (!raw) return '';
  return String(raw).trim().replace(/^['"]|['"]$/g, '');
}

const SYSTEM_PROMPT = `당신은 한국어 일상 문장·음성 전사·문서·영수증·표 이미지를 정확한 산수로 풀어주는 계산 도우미입니다.
반드시 아래 JSON만 출력하세요. 마크다운/설명 금지.

{
  "expression": "검증 가능한 산술식 (예: 12000*3 + 4500*3)",
  "steps": ["단계1", "단계2"],
  "result": "최종 숫자만 (콤마 없이)",
  "explanation": "한 줄 한국어 요약",
  "extractedText": "파일/이미지에서 읽은 핵심 숫자·문장 요약(없으면 빈 문자열)"
}

규칙:
- 만이천원=12000, 만오천원=15000처럼 한글 금액을 숫자로 변환
- 한/하나/일=1, 두/둘/이=2, 세/셋/삼=3, 네/넷/사=4, 다섯/오=5
- 명/그릇/잔/개 등은 수량을 의미
- 이미지·PDF·표에서 금액/수량을 읽어 합계·평균·차이를 계산
- result는 숫자 문자열만 (예: "49500")`;

function extractText(payload) {
  const parts = payload?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts) || !parts.length) return null;
  const text = parts[0]?.text;
  return typeof text === 'string' ? text.trim() : null;
}

function parseJsonPayload(raw) {
  let text = (raw || '').trim();
  if (text.startsWith('```')) {
    text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim();
  }
  try {
    return JSON.parse(text);
  } catch (_) {
    const match = text.match(/\{[\s\S]*\}/);
    if (match) {
      try {
        return JSON.parse(match[0]);
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}

async function callGemini(key, model, prompt, file) {
  const parts = [{ text: `${SYSTEM_PROMPT}\n\n사용자 요청:\n${prompt}` }];
  if (file?.data && file?.mimeType) {
    parts.push({
      inline_data: {
        mime_type: file.mimeType,
        data: file.data,
      },
    });
  }

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(key)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts }],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: 'application/json',
      },
    }),
  });
  const bodyText = await res.text();
  return { ok: res.ok, status: res.status, bodyText };
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST,OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
      body: '',
    };
  }

  if (event.httpMethod !== 'POST') {
    return json(405, { error: true, message: 'POST only' });
  }

  let prompt = '';
  let file = null;
  try {
    const parsed = JSON.parse(event.body || '{}');
    prompt = (parsed.prompt || parsed.text || '').trim();
    if (parsed.file?.data && parsed.file?.mimeType) {
      file = {
        mimeType: String(parsed.file.mimeType),
        fileName: String(parsed.file.fileName || 'upload'),
        data: String(parsed.file.data),
      };
      // Netlify body size guard (~6MB base64 ≈ 4.5MB binary)
      if (file.data.length > 8 * 1024 * 1024) {
        return json(413, { error: true, message: 'File too large for /api/calculate' });
      }
    }
  } catch (_) {
    return json(400, { error: true, message: 'Invalid JSON body' });
  }

  if (!prompt) {
    return json(400, { error: true, message: 'prompt is required' });
  }

  const key = cleanKey(process.env.GEMINI_API_KEY || process.env.Gemini_API_Key);
  if (!key || key.startsWith('your_')) {
    return json(503, {
      error: true,
      message: 'GEMINI_API_KEY is not configured on the server',
    });
  }

  const models = [
    cleanKey(process.env.GEMINI_MODEL) || 'gemini-flash-latest',
    'gemini-flash-latest',
    'gemini-2.0-flash',
    'gemini-2.5-flash',
  ];

  let lastError = 'Gemini request failed';
  for (const model of [...new Set(models.filter(Boolean))]) {
    try {
      const { ok, status, bodyText } = await callGemini(key, model, prompt, file);
      if (status === 404) continue;
      if (!ok) {
        lastError = `Gemini ${model} HTTP ${status}`;
        try {
          const err = JSON.parse(bodyText);
          if (err?.error?.message) lastError = err.error.message;
        } catch (_) {
          /* keep */
        }
        continue;
      }
      const payload = JSON.parse(bodyText);
      const text = extractText(payload);
      const data = parseJsonPayload(text || '');
      if (!data || data.result == null) {
        lastError = 'Gemini returned an unparseable payload';
        continue;
      }
      return json(200, {
        expression: data.expression || String(data.result),
        steps: Array.isArray(data.steps) ? data.steps : [],
        result: String(data.result).replace(/,/g, ''),
        explanation: data.explanation || '',
        extractedText: data.extractedText || '',
        model,
      });
    } catch (err) {
      lastError = String(err?.message || err);
    }
  }

  return json(502, { error: true, message: lastError });
};
