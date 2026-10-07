import { connect, shot, sleep } from './lib.mjs';
const s = await connect();
const c = await s.ctx.newCDPSession(s.page);
const g = () => s.page.evaluate(() => ({ scale: visualViewport.scale, w: Math.round(visualViewport.width), ox: Math.round(visualViewport.offsetLeft), oy: Math.round(visualViewport.offsetTop) }));
const send = (type, pts) => c.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map(([x, y], i) => ({ x, y, id: i + 1 })) });
await send('touchStart', [[150, 400], [260, 400]]);
for (let i = 1; i <= 15; i++) { await send('touchMove', [[150 - i * 6, 400], [260 + i * 6, 400]]); await sleep(40); }
await send('touchEnd', []);
await sleep(2000);
console.log('after manual pinch', await g());
console.log(await shot(s, 'pz_3'));
process.exit(0);
