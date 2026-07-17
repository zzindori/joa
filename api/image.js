export const config = { maxDuration: 60 };

const VM_URL = 'https://api.wowhit.org';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();

  const { prompt, apiKey, subCode, referenceImage } = req.body;
  if (!prompt) return res.status(400).json({ error: 'prompt required' });

  const key = apiKey || process.env.GEMINI_API_KEY;
  if (!key) return res.status(500).json({ error: 'API 키가 없습니다.' });

  // 구독 코드 있으면 서버 쿼터 차감 (개인 API키 사용자는 패스)
  if (subCode && !apiKey) {
    try {
      const normalized = subCode.trim().toUpperCase().replace(/[-\s]/g, '');
      const vmRes = await fetch(`${VM_URL}/use`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-vm-secret': process.env.VM_SECRET },
        body: JSON.stringify({ code: normalized }),
      });
      const quota = await vmRes.json();
      if (!quota.ok) return res.status(403).json({ error: quota.error });
    } catch (e) {
      // 쿼터 서버 장애 시 생성 허용 (서버 다운 방어)
      console.error('쿼터 서버 오류 (통과):', e.message);
    }
  }

  const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash-image';

  try {
    const apiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              ...(referenceImage ? [{ inlineData: { mimeType: 'image/png', data: referenceImage } }] : []),
              {
                text: referenceImage
                  ? `Keep exactly the same person's face and identity from the reference image. ${prompt}, vertical 9:16 portrait aspect ratio`
                  : `${prompt}, vertical 9:16 portrait aspect ratio`,
              },
            ],
          }],
          generationConfig: { responseModalities: ['IMAGE'] },
        }),
      }
    );

    if (!apiRes.ok) {
      const text = await apiRes.text();
      console.error(`Gemini error ${apiRes.status}:`, text.slice(0, 300));
      if (apiRes.status === 503) return res.status(503).json({ error: 'Gemini 서버가 잠시 바쁩니다. 잠시 후 다시 시도해주세요.' });
      return res.status(apiRes.status).setHeader('Content-Type', 'application/json').send(text);
    }

    const data = await apiRes.json();
    const parts = data?.candidates?.[0]?.content?.parts ?? [];
    const imagePart = parts.find(p => p.inlineData);

    if (!imagePart) {
      return res.status(502).json({ error: '이미지 데이터가 없습니다.' });
    }

    return res.status(200).json({
      data: [{ b64_json: imagePart.inlineData.data }],
    });
  } catch (e) {
    console.error('image gen error:', e.message);
    return res.status(502).json({ error: e.message });
  }
}
