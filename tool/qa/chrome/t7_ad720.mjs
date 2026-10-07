import { open, shot, sleep, report } from './common.mjs';
const dev = process.argv[2] || 'laptop'; const th = process.argv[3] || 'dark';
const s = await open({ theme: th, device: dev });
await sleep(2000);
const P = s.page; const vp = P.viewportSize(); await P.mouse.move(vp.width / 2, vp.height / 2);
await P.mouse.wheel(0, 130); await sleep(2500); await P.mouse.wheel(0, 130); await sleep(9000);
console.log('ad late', await shot(s, `t7ad_${dev}_${th}_late`));
await sleep(1500); console.log('ad late2', await shot(s, `t7ad_${dev}_${th}_late2`));
console.log(report(s)); await s.close();
