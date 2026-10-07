import { openM, shot, sleep, report, dragStart, dragMove, dragEnd } from './lib.mjs';
const dev = process.argv[2] || 'iphone', theme = process.argv[3] || 'dark';
const s = await openM(dev, theme);
const vp = s.page.viewportSize(); const x = vp.width / 2; let y = vp.height * 0.8;
await sleep(1500);
await dragStart(s, x, y);
const total = vp.height * 0.95; const stepsN = 6; const files = [];
for (let k = 1; k <= stepsN; k++) {
  const target = y - total / stepsN;
  for (let i = 1; i <= 6; i++) { await dragMove(s, x, y + (target - y) * i / 6); await sleep(40); }
  y = target; await sleep(900);
  files.push(await shot(s, `m3_iris_${k}`));
}
await dragEnd(s); await sleep(2500);
files.push(await shot(s, 'm3_iris_released'));
console.log(files.join(' '));
console.log(report(s));
await s.close();
