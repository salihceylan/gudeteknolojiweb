import { connect, goto, shot, tapCss, sleep, rep, screencap } from './lib.mjs';
const s = await connect();
await goto(s, 'http://localhost:8099/');
tapCss(375, 30); await sleep(2500);
console.log(await shot(s, 'm_00'));
console.log(rep(s));
process.exit(0);
