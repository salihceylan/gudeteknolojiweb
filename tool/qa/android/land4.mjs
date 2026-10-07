import { connect, shot, cdpDrag, cdpTap, sleep } from './lib.mjs';
const s = await connect();
await cdpTap(s, 820, 30); await sleep(2500);
for (let i = 0; i < 4; i++) { await cdpDrag(s, 600, 280, 90, { steps: 10, stepMs: 25 }); await sleep(1200); console.log(i, await shot(s, 'ls4_' + i)); }
process.exit(0);
