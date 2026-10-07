import { open, shot, sleep, report } from './common.mjs';
const th = process.argv[2] || 'dark';
const dev = process.argv[3] || 'laptop';
const s = await open({ theme: th, device: dev, menu: true });
await sleep(2500);
const P = s.page; const vp = P.viewportSize();
console.log('open', await shot(s, `t11_${dev}_open`));
await P.mouse.move(vp.width - 200, vp.height / 2);
for (let i = 0; i < 6; i++) { await P.mouse.wheel(0, 100); await sleep(40); }
await sleep(1500);
console.log('scrolled panel', await shot(s, `t11_${dev}_panel_scrolled`));
console.log(report(s));
await s.close();
