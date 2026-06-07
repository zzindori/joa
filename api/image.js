const VM_URL = 'http://152.67.208.156:3000';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();

  const { prompt, apiKey, subCode } = req.body;
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
      return res.status(500).json({ error: '쿼터 서버 오류: ' + e.message });
    }
  }

  try {
    const apiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=${key}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: `${prompt}, vertical 9:16 portrait aspect ratio` }] }],
          generationConfig: { responseModalities: ['IMAGE'] },
        }),
      }
    );

    if (!apiRes.ok) {
      const text = await apiRes.text();
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
    return res.status(502).json({ error: e.message });
  }
}
