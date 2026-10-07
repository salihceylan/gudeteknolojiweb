import { connect, shot, swipeCss, sleep, adb, screencap } from './lib.mjs';
const s = await connect();
const origin = () => s.page.evaluate(() => Math.round(performance.timeOrigin));
const o1 = await origin();
swipeCss(206, 200, 206, 600, 600); await sleep(400);
screencap('ptr_mid');
await sleep(4000);
const o2 = await origin().catch(() => 'err');
console.log('timeOrigin same (no reload)?', o1 === o2, o1, o2);
screencap('ptr_after');
// fast fling
swipeCss(206, 150, 206, 700, 120); await sleep(3000);
const o3 = await origin().catch(() => 'err');
console.log('after fling same?', o1 === o3);
process.exit(0);
