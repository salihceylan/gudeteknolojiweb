import { open, shot, sleep, report, tap } from './common.mjs';
const th = process.argv[2] || 'dark';
const which = (process.argv[3] || '0,1,2,3,4,5').split(',').map(Number);
const s = await open({ theme: th });
await sleep(1500);
const MENU = [1388, 32];
const ys = [172, 225, 278, 331, 384, 437];
for (const i of which) {
  await tap(s, ...MENU); await sleep(1800);
  await tap(s, 1240, ys[i]); await sleep(300);
  const f1 = await shot(s, `t3B_link${i}_mid`);
  await sleep(2500);
  console.log(i, await shot(s, `t3B_link${i}_end`));
  await tap(s, 72, 31); await sleep(2200);
}
console.log(report(s));
await s.close();
