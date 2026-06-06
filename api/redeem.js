import crypto from 'crypto';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();

  const { code } = req.body || {};
  if (!code) return res.status(400).json({ error: '코드를 입력해주세요' });

  const secret = process.env.CODE_SECRET;
  if (!secret) return res.status(500).json({ error: '서버 설정 오류' });

  // Normalize: remove dashes/spaces, uppercase
  const normalized = code.trim().toUpperCase().replace(/[-\s]/g, '');

  // Format: JOA + 4-digit index + 6-char hex = JOA0001ABCDEF (13 chars)
  const match = normalized.match(/^JOA(\d{4})([A-F0-9]{6})$/);
  if (!match) return res.status(400).json({ error: '유효하지 않은 코드 형식입니다' });

  const [, index, checksum] = match;
  const expected = crypto
    .createHmac('sha256', secret)
    .update(`JOA:ANNUAL:${index}`)
    .digest('hex')
    .slice(0, 6)
    .toUpperCase();

  if (expected !== checksum) {
    return res.status(400).json({ error: '유효하지 않은 코드입니다' });
  }

  const expiresAt = new Date();
  expiresAt.setMonth(expiresAt.getMonth() + 1);

  return res.status(200).json({
    success: true,
    expiresAt: expiresAt.toISOString().split('T')[0],
  });
}
