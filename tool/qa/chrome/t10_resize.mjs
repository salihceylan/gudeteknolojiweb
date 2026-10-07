import { open, shot, sleep, report, tap, measureFrames } from './common.mjs';
const th = process.argv[2] || 'dark';
const mode = process.argv[3] || 'hero';
const s = await open({ theme: th });
await sleep(2000);
const P = s.page;
if (mode === 'services') { await tap(s, 907, 29); await sleep(3500); }
if (mode === 'camera') { await tap(s, 755, 29); await sleep(3500); }
const sizes = [[1440, 900], [1024, 768], [768, 1024], [390, 844], [1440, 900]];
for (const [w, h] of sizes) {
  await P.setViewportSize({ width: w, height: h });
  await sleep(3500);
  const f = await measureFrames(s, 1200);
  console.log(mode, w, h, JSON.stringify(f), await shot(s, `t10_${mode}_${w}x${h}`));
}
console.log(report(s));
await s.close();
