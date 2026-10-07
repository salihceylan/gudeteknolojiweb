import { connect, shot, tapCss, sleep } from './lib.mjs';
const s = await connect();
await shot(s, 'ti_menu_state');
tapCss(375, 30); await sleep(2500); // kapat (menü açık kalmıştı)
console.log('after close', await shot(s, 'ti_a'));
tapCss(375, 30); await sleep(2500); tapCss(104, 215); await sleep(5000);
tapCss(90, 377); await sleep(5000);
console.log('after Teklif Isteyin', await shot(s, 'ti_b'));
process.exit(0);
