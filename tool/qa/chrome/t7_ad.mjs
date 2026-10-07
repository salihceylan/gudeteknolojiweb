import { open, shot, sleep, report, tap, startCast } from './common.mjs';
import fs from 'node:fs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th });
await sleep(2000);
const P = s.page; await P.mouse.move(700, 300);
const cast = await startCast(s, 'ad_' + th, { quality: 75 });
await tap(s, 827, 29);
await sleep(13000);
const fr = await cast.stop();
console.log('frames', fr.length, 'span', fr.at(-1).t);
fs.writeFileSync(cast.frames[0].file.replace(/\d+\.jpg$/, 'times.json'), JSON.stringify(fr.map((f) => f.t)));
// ekran dışına çık, 4 sn sonra iki kare karşılaştırması için shot
await tap(s, 907, 29); await sleep(3000);
console.log(report(s));
await s.close();
