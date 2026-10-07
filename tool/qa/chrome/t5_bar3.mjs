import { open, shot, sleep, report } from './common.mjs';
const s = await open({ theme: 'dark' });
await sleep(2000);
const P = s.page;
await P.mouse.move(400, 300);
for (let i = 0; i < 4; i++) { await P.mouse.wheel(0, 100); await sleep(30); }
await sleep(2500);
await P.mouse.move(1436, 300); await sleep(500);
await P.mouse.move(1436, 190); await sleep(300); await P.mouse.down();
for (let i = 1; i <= 10; i++) { await P.mouse.move(1436, 190 + i * 30); await sleep(60); }
await sleep(500);
console.log('dragging', await shot(s, 't5b3_drag'));
await P.mouse.up(); await sleep(3000);
console.log('after', await shot(s, 't5b3_after'));
console.log(report(s)); await s.close();
