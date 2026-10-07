import { openM, shot, sleep, report, dragStart, dragMove, dragEnd } from './lib.mjs';
const dev = process.argv[2] || 'tablet', theme = process.argv[3] || 'dark', pre = +(process.argv[4] || 2), extra = +(process.argv[5] || 0), n = +(process.argv[6] || 8);
const s = await openM(dev, theme);
const vp = s.page.viewportSize(); const x = vp.width / 2;
await sleep(1500);
async function d(frac) { const y0 = vp.height * 0.85, y1 = y0 - vp.height * frac; await dragStart(s, x, y0); for (let k = 1; k <= 10; k++) { await dragMove(s, x, y0 + (y1 - y0) * k / 10); await sleep(35); } await sleep(350); await dragEnd(s); await sleep(1800); }
for (let i = 0; i < pre; i++) await d(0.6);
if (extra) await d(extra);
for (let i = 0; i < n; i++) { console.log(await shot(s, `m12_ad_${i}`)); await sleep(1000); }
console.log(report(s));
await s.close();
