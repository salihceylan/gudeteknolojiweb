import { open, shot, sleep, report } from './common.mjs';
const dev = process.argv[2] || 'laptop'; const th = process.argv[3] || 'dark'; const n = +(process.argv[4] || 9);
const s = await open({ theme: th, device: dev });
await sleep(2000);
const P = s.page; const vp = P.viewportSize(); await P.mouse.move(vp.width / 2, vp.height / 2);
for (let i = 1; i <= n; i++) { await P.mouse.wheel(0, 130); await sleep(3200); console.log(i, await shot(s, `t9w_${dev}_${th}_${i}`)); }
console.log(report(s)); await s.close();
