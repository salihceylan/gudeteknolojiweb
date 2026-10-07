import { connect, shot, tapCss, sleep } from './lib.mjs';
const s = await connect();
tapCss(375, 30); await sleep(2200); tapCss(104, 215); await sleep(3500);
const t0 = Date.now();
for (let i = 0; i < 9; i++) { const f = await shot(s, 'ad_' + i); console.log(i, Date.now() - t0); await sleep(300); }
process.exit(0);
