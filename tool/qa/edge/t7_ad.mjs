import { openE, shotE, arg, sleep, report, measureFrames } from './lib2.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const s = await openE({ browser, size, theme, scroll: 1.95 });
const t0 = Date.now();
const files = [];
for (let i = 0; i < 12; i++) { files.push(await shotE(s, `ad_${String(i).padStart(2, '0')}`)); console.log(i, Date.now() - t0, 'ms'); await sleep(500); }
console.log(files.join(' '));
console.log(JSON.stringify(await measureFrames(s, 1500)));
console.log(report(s));
await s.close();
