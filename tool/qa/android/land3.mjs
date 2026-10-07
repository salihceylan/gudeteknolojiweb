import { connect, geom, shot, cdpDrag, cdpTap, sleep, rep } from './lib.mjs';
const s = await connect();
await cdpTap(s, 820, 30); await sleep(3000);
console.log('menu', await shot(s, 'ls3_menu'));
// panel icindeki kaydirma: parmakla yukari surukle
await cdpDrag(s, 600, 250, 60, { steps: 12, stepMs: 30 }); await sleep(1500);
console.log('menu scrolled', await shot(s, 'ls3_menu2'));
await cdpTap(s, 820, 30); await sleep(2500);
console.log('closed', await shot(s, 'ls3_closed'));
console.log(rep(s));
process.exit(0);
