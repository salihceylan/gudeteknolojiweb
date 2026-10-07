import { openM, shot, sleep, report, dragStart, dragMove, dragEnd } from './lib.mjs';
const dev = process.argv[2] || 'iphone', theme = process.argv[3] || 'dark';
const s = await openM(dev, theme, 'scroll=50');
const vp = s.page.viewportSize(); const x = vp.width / 2;
await sleep(3000);
console.log('A', await shot(s, 'm9_bot_A_jump'));
async function pull(dy, hold = 350) {
  const y0 = vp.height * 0.7, y1 = y0 - dy;
  await dragStart(s, x, y0);
  for (let k = 1; k <= 8; k++) { await dragMove(s, x, y0 + (y1 - y0) * k / 8); await sleep(35); }
  await sleep(hold); await dragEnd(s);
}
await pull(250); await sleep(2500); console.log('B', await shot(s, 'm9_bot_B_pull'));
await pull(250); await sleep(2500); console.log('C', await shot(s, 'm9_bot_C_pull2'));
await pull(-200); await sleep(2500); console.log('D', await shot(s, 'm9_bot_D_up'));
await pull(400); await sleep(2500); console.log('E', await shot(s, 'm9_bot_E_down'));
console.log(report(s));
await s.close();
