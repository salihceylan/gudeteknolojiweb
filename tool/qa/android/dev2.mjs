import { connect, shot, tapCss, sleep } from './lib.mjs';
const s = await connect();
console.log(await shot(s, 'dv2_0'));
tapCss(205, 245); await sleep(700);
console.log(await shot(s, 'dv2_1'));
await sleep(3500);
console.log(await shot(s, 'dv2_2'));
process.exit(0);
