import { openM, shot, sleep, report, dragStart, dragMove, dragEnd, tap } from './lib.mjs';
const dev = process.argv[2] || 'iphone', theme = process.argv[3] || 'dark', pre = +(process.argv[4] || 7), bx = +(process.argv[5] || 195), by = +(process.argv[6] || 300);
const s = await openM(dev, theme);
const vp = s.page.viewportSize(); const x = vp.width / 2;
await sleep(1500);
for (let i = 0; i < pre; i++) { const y0 = vp.height * 0.85, y1 = y0 - vp.height * 0.6; await dragStart(s, x, y0); for (let k = 1; k <= 10; k++) { await dragMove(s, x, y0 + (y1 - y0) * k / 10); await sleep(35); } await sleep(350); await dragEnd(s); await sleep(1700); }
console.log(await shot(s, 'm14_before'));
await tap(s, bx, by); await sleep(500); console.log(await shot(s, 'm14_t05'));
await sleep(1200); console.log(await shot(s, 'm14_t17'));
await sleep(2500); console.log(await shot(s, 'm14_t42'));
await sleep(4000); console.log(await shot(s, 'm14_t82'));
console.log(report(s));
await s.close();
