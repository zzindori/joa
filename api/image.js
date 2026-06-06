export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('X-JoA-Version', 'v3-url-to-b64');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();

  try {
    const apiRes = await fetch('https://api.x.ai/v1/images/generations', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.XAI_API_KEY}`,
      },
      body: JSON.stringify(req.body),
    });

    if (!apiRes.ok) {
      const text = await apiRes.text();
      return res.status(apiRes.status).setHeader('Content-Type', 'application/json').send(text);
    }

    const data = await apiRes.json();
    const item = data?.data?.[0];

    // b64_json으로 이미 왔으면 바로 반환
    if (item?.b64_json) {
      return res.status(200).json(data);
    }

    // URL로 왔으면 서버에서 fetch → base64 변환 (CORS 우회)
    if (item?.url) {
      const imgRes = await fetch(item.url);
      if (!imgRes.ok) {
        return res.status(502).json({ error: `이미지 다운로드 실패: ${imgRes.status}` });
      }
      const buffer = Buffer.from(await imgRes.arrayBuffer());
      return res.status(200).json({
        ...data,
        data: [{ ...item, b64_json: buffer.toString('base64'), url: undefined }],
      });
    }

    return res.status(502).json({ error: '지원되지 않는 응답 형식' });
  } catch (e) {
    return res.status(502).json({ error: e.message });
  }
}
