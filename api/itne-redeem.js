import crypto from 'crypto';

const VM_URL = 'http://152.67.208.156:3000';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();

  const { code } = req.body || {};
  if (!code) return res.status(400).json({ error: '코드를 입력해주세요' });

  const secret = process.env.ITNE_CODE_SECRET;
  if (!secret) return res.status(500).json({ error: '서버 설정 오류' });

  const normalized = code.trim().toUpperCase().replace(/[-\s]/g, '');
  const match = normalized.match(/^ITNE(\d{2})(\d{4})([A-F0-9]{6})$/);
  if (!match) return res.status(400).json({ error: '유효하지 않은 코드 형식입니다' });

  const [, months, serial, checksum] = match;
  const expected = crypto
    .createHmac('sha256', secret)
    .update(`ITNE:${months}:${serial}`)
    .digest('hex')
    .slice(0, 6)
    .toUpperCase();

  if (expected !== checksum) {
    return res.status(400).json({ error: '유효하지 않은 코드입니다' });
  }

  try {
    const vmRes = await fetch(`${VM_URL}/itne/redeem`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-vm-secret': process.env.VM_SECRET },
      body: JSON.stringify({ code: normalized }),
    });
    const data = await vmRes.json();
    if (!vmRes.ok) return res.status(400).json({ error: data.error || '이미 사용된 코드입니다' });
    return res.status(200).json({ success: true, months: parseInt(months, 10) });
  } catch (e) {
    return res.status(500).json({ error: '서버 오류: ' + e.message });
  }
}
