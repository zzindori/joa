#!/usr/bin/env node
// 사용법: CODE_SECRET=your_secret node scripts/gen_codes.js [개수] [시작번호]
// 예)   CODE_SECRET=abc123 node scripts/gen_codes.js 20 1
//
// 생성된 코드를 네이버 스마트스토어 디지털 상품 > 자동발송 코드 목록에 등록하세요.

import crypto from 'crypto';

const secret = process.env.CODE_SECRET;
if (!secret) {
  console.error('오류: CODE_SECRET 환경변수를 설정하세요');
  console.error('예) CODE_SECRET=your_secret node scripts/gen_codes.js 10');
  process.exit(1);
}

const count = parseInt(process.argv[2]) || 10;
const start = parseInt(process.argv[3]) || 1;

console.log(`# JoA 연간 이용권 코드`);
console.log(`# 생성일: ${new Date().toISOString().split('T')[0]}`);
console.log(`# ${count}개 (${start}~${start + count - 1}번)`);
console.log('');

for (let i = start; i < start + count; i++) {
  const index = String(i).padStart(4, '0');
  const checksum = crypto
    .createHmac('sha256', secret)
    .update(`JOA:ANNUAL:${index}`)
    .digest('hex')
    .slice(0, 6)
    .toUpperCase();
  // Format: JOA-0001-ABCDEF
  console.log(`JOA-${index}-${checksum}`);
}
