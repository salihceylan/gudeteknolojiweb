import { open, shot, sleep, report } from './common.mjs';
const s = await open({ theme: 'dark' });
await sleep(2000);
const P = s.page;
// 1) tekerlek üst çubuk üzerinde
await P.mouse.move(400, 30);
for (let i = 0; i < 4; i++) { await P.mouse.wheel(0, 100); await sleep(30); }
await sleep(2500);
console.log('wheel over topbar', await shot(s, 't5b2_wheel_topbar'));
// 2) tekerlek aynı kaydırma, gövde üzerinde (kontrol)
await P.mouse.move(400, 300);
for (let i = 0; i < 4; i++) { await P.mouse.wheel(0, 100); await sleep(30); }
await sleep(2500);
console.log('wheel over body', await shot(s, 't5b2_wheel_body'));
// 3) çubuk sürükleme (y>64)
await P.mouse.move(1436, 300); await sleep(800);
console.log('hover', await shot(s, 't5b2_hover'));
await P.mouse.move(1436, 100); await sleep(300); await P.mouse.down();
for (let i = 1; i <= 10; i++) { await P.mouse.move(1436, 100 + i * 40); await sleep(60); }
console.log('dragging', await shot(s, 't5b2_drag'));
await P.mouse.up(); await sleep(3000);
console.log('after', await shot(s, 't5b2_after'));
console.log(report(s)); await s.close();
