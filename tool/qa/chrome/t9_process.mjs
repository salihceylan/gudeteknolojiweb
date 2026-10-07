import { open, shot, sleep, report, tap, startCast } from './common.mjs';
import fs from 'node:fs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th });
await sleep(2000);
const P = s.page;
await tap(s, 907, 29); await sleep(3500);
const cast = await startCast(s, 'proc_' + th, { quality: 70 });
await tap(s, 981, 29);
await sleep(4500);
const fr = await cast.stop();
fs.writeFileSync(cast.frames[0].file.replace(/\d+\.jpg$/, 'times.json'), JSON.stringify(fr.map((f) => f.t)));
console.log('frames', fr.length);
// tekrar: aşağı-yukarı gidip gelince çizgi yeniden oynuyor mu?
await tap(s, 907, 29); await sleep(3000);
const c2 = await startCast(s, 'proc2_' + th, { quality: 70 });
await tap(s, 981, 29); await sleep(3000);
const f2 = await c2.stop();
fs.writeFileSync(c2.frames[0].file.replace(/\d+\.jpg$/, 'times.json'), JSON.stringify(f2.map((f) => f.t)));
console.log('frames2', f2.length);
// hover'lar (koyu)
await P.mouse.move(1000, 330); await sleep(800);
console.log(report(s));
await s.close();
