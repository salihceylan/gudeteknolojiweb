import { openM, shot, sleep, report, measureFrames } from './lib.mjs';
const dev = process.argv[2] || 'iphone', theme = process.argv[3] || 'dark', sc = process.argv[4] || '2.6', n = +(process.argv[5] || 9), gap = +(process.argv[6] || 1100);
const s = await openM(dev, theme, 'scroll=' + sc);
await sleep(2500);
for (let i = 0; i < n; i++) { console.log(await shot(s, `m10_ad_${i}`)); await sleep(gap); }
console.log(report(s));
await s.close();
