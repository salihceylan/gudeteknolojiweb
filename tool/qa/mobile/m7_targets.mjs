import { openM, sleep, semOn, boxesNow } from './lib.mjs';
const dev = process.argv[2] || 'smallPhone', theme = process.argv[3] || 'dark', q = process.argv[4] || '';
const s = await openM(dev, theme, q);
await sleep(2500);
console.log('sem nodes', await semOn(s));
const boxes = await boxesNow(s);
console.log(dev, theme, q, 'nodes', boxes.length);
for (const b of boxes) if (b.role === 'button' || b.role === 'link') console.log(`${b.role} | ${b.label} @${b.x},${b.y} ${b.w}x${b.h}${(b.w < 44 || b.h < 44) ? '   <44' : ''}`);
await s.close();
