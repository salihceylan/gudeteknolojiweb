import { connect, measureFrames, tapCss, sleep } from './lib.mjs';
const s = await connect();
tapCss(375, 30); await sleep(2000); tapCss(117, 261); await sleep(3000);
for (let i = 0; i < 5; i++) { console.log('services t+', 3 + i * 3, JSON.stringify(await measureFrames(s, 2000))); await sleep(1000); }
tapCss(375, 30); await sleep(2000); tapCss(103, 399); await sleep(6000);
for (let i = 0; i < 2; i++) console.log('contact', JSON.stringify(await measureFrames(s, 2000)));
process.exit(0);
