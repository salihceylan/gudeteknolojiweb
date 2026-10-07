import { open, shot, sleep, report } from './common.mjs';
const dev = process.argv[2] || 'desktop'; const th = process.argv[3] || 'dark'; const n = +(process.argv[4] || 8);
const sc = process.argv[5]; const s = await open({ device: dev, theme: th, scroll: sc });
await sleep(1500);
const P = s.page; const vp = P.viewportSize();
await P.mouse.move(vp.width / 2, vp.height / 2);
const out = [];
for (let i = 0; i < n; i++) {
  await P.mouse.wheel(0, 100);
  await sleep(2600);
  out.push(await shot(s, `t5_${dev}${sc||''}_notch${i + 1}`));
}
console.log(out.join('\n'));
console.log(report(s));
await s.close();
