import { connect, shot, tapCss, sleep, probeTouches, touches } from './lib.mjs';
const s = await connect();
await s.page.evaluate(() => { window.__t = null; });
await probeTouches(s);
tapCss(47, 30); await sleep(5000);
console.log(JSON.stringify(await touches(s)));
console.log('logo->top', await shot(s, 'h2_0'));
process.exit(0);
