import { open, shot, sleep, report, startCast } from './common.mjs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th });
await sleep(2000);
const P = s.page; await P.mouse.move(720, 450);
let cast = await startCast(s, 'iris_fwd_' + th, { quality: 60 });
for (let i = 0; i < 58; i++) { await P.mouse.wheel(0, 15); await sleep(100); }
await sleep(2500);
let fr = await cast.stop();
console.log('fwd frames', fr.length, fr.length > 0 ? fr[fr.length - 1].t : 0);
cast = await startCast(s, 'iris_back_' + th, { quality: 60 });
for (let i = 0; i < 58; i++) { await P.mouse.wheel(0, -15); await sleep(100); }
await sleep(2500);
fr = await cast.stop();
console.log('back frames', fr.length);
console.log(report(s));
await s.close();
