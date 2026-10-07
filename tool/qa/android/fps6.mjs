import { connect, countFlutterFrames, cdpDrag, cdpRelease, tapCss, sleep } from './lib.mjs';
const s = await connect();
tapCss(375, 30); await sleep(2000); tapCss(117, 261); await sleep(5000);
console.log('services snapped:', await countFlutterFrames(s, 2000));
await cdpDrag(s, 206, 600, 600 - 120, { steps: 10, hold: true }); await sleep(1500);
console.log('scrolled +120 (held):', await countFlutterFrames(s, 2000));
await cdpDrag(s, 206, 480, 480 + 120, { steps: 10, hold: true, }); await sleep(1500); // geri (ayni parmak degil ama ok)
console.log('back to 0 (held):', await countFlutterFrames(s, 2000));
await cdpRelease(s); await sleep(3000);
console.log('released:', await countFlutterFrames(s, 2000));
process.exit(0);
