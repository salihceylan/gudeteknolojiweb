import { open, URL, sleep, report, dragStart, dragMove, dragEnd, cdp } from './lib.mjs';
const dev = process.argv[2] || 'iphone', n = +(process.argv[3] || 16), frac = +(process.argv[4] || 0.8);
const s = await open({ device: dev, theme: 'dark', url: URL, query: 'theme=dark' });
await s.page.evaluate(() => { window.__raf = 0; const o = window.requestAnimationFrame.bind(window); window.requestAnimationFrame = (cb) => { window.__raf++; return o(cb); }; });
const c = await cdp(s); await c.send('Performance.enable');
const vp = s.page.viewportSize(); const x = vp.width / 2;
const heap = async () => (await c.send('Performance.getMetrics')).metrics.find(m => m.name === 'JSHeapUsedSize').value / 1e6;
for (let i = 0; i < n; i++) {
  await sleep(600);
  const r0 = await s.page.evaluate(() => window.__raf); const h0 = await heap();
  await sleep(2500);
  const r1 = await s.page.evaluate(() => window.__raf);
  console.log(`step ${i}: rafPerSec=${((r1 - r0) / 2.5).toFixed(1)} heapMB=${(await heap()).toFixed(1)}`);
  const y0 = vp.height * 0.85, y1 = y0 - vp.height * frac;
  await dragStart(s, x, y0); for (let k = 1; k <= 10; k++) { await dragMove(s, x, y0 + (y1 - y0) * k / 10); await sleep(30); } await sleep(300); await dragEnd(s); await sleep(1500);
}
console.log(report(s));
await s.close();
