import { openE, shotE, arg, sleep, report, waitForFlutter, URL0 } from './lib2.mjs';
const theme = arg(1, 'dark');
const sizes = (arg(0, '900x700,1366x640,1280x560')).split(',').map((x) => x.split('x').map(Number));
const s = await openE({ browser: 'edge', size: 'd1440', theme, reduce: true });
for (const [w, h] of sizes) {
  await s.page.setViewportSize({ width: w, height: h });
  for (const sc of [0, 0.95, 1.95, 2.85]) {
    await s.page.goto(`${URL0}?theme=${theme}&scroll=${sc}`, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page, 90000); await sleep(1800);
    s.size = 'd1440';
    const f = await shotE(s, `sz_${w}x${h}_${String(sc).replace('.', '_')}`);
  }
  console.log('done', w, h, await s.page.evaluate(() => [document.documentElement.scrollWidth, innerWidth]));
}
console.log(report(s));
await s.close();
