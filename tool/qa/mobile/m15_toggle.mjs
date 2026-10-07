import { openM, shot, sleep, report, dragStart, dragMove, dragEnd, tap, waitForFlutter } from './lib.mjs';
const dev = process.argv[2] || 'iphone', pre = +(process.argv[3] || 1), tag = process.argv[4] || 'cam', tx = +(process.argv[5] || 306), ty = +(process.argv[6] || 32);
const s = await openM(dev, 'dark');
const vp = s.page.viewportSize(); const x = vp.width / 2;
async function go() { await sleep(1500); for (let i = 0; i < pre; i++) { const y0 = vp.height * 0.85, y1 = y0 - vp.height * 0.6; await dragStart(s, x, y0); for (let k = 1; k <= 10; k++) { await dragMove(s, x, y0 + (y1 - y0) * k / 10); await sleep(35); } await sleep(350); await dragEnd(s); await sleep(1700); } }
await go();
console.log(await shot(s, `m15_${tag}_dark`));
await tap(s, tx, ty); await sleep(250); console.log(await shot(s, `m15_${tag}_mid`));
await sleep(2200); console.log(await shot(s, `m15_${tag}_toggled`));
console.log('ls', await s.page.evaluate(() => localStorage.getItem('gude-theme')));
await s.page.goto('http://localhost:8099/', { waitUntil: 'load' }); await waitForFlutter(s.page);
await go(); console.log(await shot(s, `m15_${tag}_fresh`));
console.log(report(s));
await s.close();
