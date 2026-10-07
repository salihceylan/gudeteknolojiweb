import { openM, shot, sleep, tap, waitForFlutter } from './lib.mjs';
const link = process.argv[2] === 'p' ? 169 + 46 : 169;
const s = await openM('iphone', 'dark', 'menu=1');
await sleep(3000);
await tap(s, 194, link);
const out = [];
for (const t of [400, 600, 800, 1500, 3000]) { await sleep(t); out.push(await shot(s, 'dbg3_' + t)); }
console.log(out.length);
await s.close();
