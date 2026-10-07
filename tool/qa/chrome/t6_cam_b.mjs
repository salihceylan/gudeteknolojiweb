import { open, shot, sleep, report } from './common.mjs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th, scroll: 0.95 });
await sleep(3500);
const P = s.page;
await P.mouse.move(600, 450); await P.mouse.down();
let x = 600;
// 360 deg ~ 835px*2 ... pi/835 rad/px -> 45deg = 209px (sağa sürükleme)
for (let a = 1; a <= 8; a++) {
  for (let i = 0; i < 7; i++) { x += 30; await P.mouse.move(x, 450); await sleep(30); }
  await sleep(500);
  console.log(a * 45, await shot(s, `t6b_${a * 45}`));
  if (x > 1380) { await P.mouse.up(); await P.mouse.move(300, 450); await P.mouse.down(); x = 300; }
}
await P.mouse.up();
console.log(report(s));
await s.close();
