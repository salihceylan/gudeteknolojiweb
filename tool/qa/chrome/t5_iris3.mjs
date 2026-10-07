import { open, shot, sleep, report } from './common.mjs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th });
const P = s.page; await P.emulateMedia({ reducedMotion: 'reduce' });
await sleep(2000); await P.mouse.move(720, 450);
const D = 855;
const seq = [[0.1, 85.5], [0.25, 128.25], [0.4, 128.25], [0.5, 85.5], [0.6, 85.5], [0.75, 128.25], [0.9, 128.25], [1.0, 85.5]];
for (const [p, d] of seq) { await P.mouse.wheel(0, d); await sleep(1600); console.log('fwd', p, await shot(s, `t5i3_fwd_${p}`)); }
for (const [p, d] of [[0.75, 213.75], [0.5, 213.75], [0.25, 213.75]]) { await P.mouse.wheel(0, -d); await sleep(1600); console.log('back', p, await shot(s, `t5i3_back_${p}`)); }
console.log(report(s));
await s.close();
