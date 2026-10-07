import { openM, shot, sleep, report, dragStart, dragMove, dragEnd } from './lib.mjs';
const dev = process.argv[2] || 'iphone', theme = process.argv[3] || 'dark', n = +(process.argv[4] || 16), frac = +(process.argv[5] || 0.6), tag = process.argv[6] || 'w';
const s = await openM(dev, theme);
const vp = s.page.viewportSize(); const x = vp.width / 2;
await sleep(1800);
const files = [];
for (let i = 0; i < n; i++) {
  files.push(await shot(s, `m8_${tag}_${String(i).padStart(2, '0')}`));
  const y0 = vp.height * 0.85, dist = vp.height * frac, y1 = y0 - dist;
  await dragStart(s, x, y0);
  for (let k = 1; k <= 10; k++) { await dragMove(s, x, y0 + (y1 - y0) * k / 10); await sleep(35); }
  await sleep(350);   // parmak durur: ivme sıfır
  await dragEnd(s); await sleep(1700);
}
console.log(files.length, 'shots');
console.log(report(s));
await s.close();
