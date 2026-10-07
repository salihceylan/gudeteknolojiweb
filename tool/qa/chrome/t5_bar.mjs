import { open, shot, sleep, report } from './common.mjs';
const s = await open({ theme: 'dark' });
await sleep(2000);
const P = s.page;
await P.mouse.move(1436, 300); await sleep(1500);
console.log('hover edge', await shot(s, 't5b_hover_edge'));
await P.mouse.move(1436, 60); await sleep(500);
await P.mouse.down();
for (let i = 1; i <= 10; i++) { await P.mouse.move(1436, 60 + i * 30); await sleep(60); }
console.log('dragging', await shot(s, 't5b_drag'));
await P.mouse.up(); await sleep(3000);
console.log('after', await shot(s, 't5b_after'));
console.log(report(s)); await s.close();
