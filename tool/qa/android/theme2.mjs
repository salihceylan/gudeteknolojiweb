import { connect, shot, tapCss, sleep, rep, probeTouches, touches } from './lib.mjs';
const s = await connect();
await probeTouches(s);
tapCss(327, 30); await sleep(3500);
console.log(JSON.stringify(await touches(s)), await shot(s, 'th2_a'));
console.log(await s.page.evaluate(() => [localStorage.getItem('gude-theme'), Object.keys(localStorage)]));
tapCss(327, 32); await sleep(3500);
console.log(JSON.stringify(await touches(s)), await shot(s, 'th2_b'));
process.exit(0);
