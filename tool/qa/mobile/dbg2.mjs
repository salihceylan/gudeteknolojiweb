import { openM, shot, sleep } from './lib.mjs';
const out = [];
for (const sc of ['2.6','3','4','5','6','8']) {
  const s = await openM('iphone', 'dark', 'scroll=' + sc);
  await sleep(3500);
  out.push(await shot(s, 'dbg2_' + sc));
  await s.close();
}
console.log(out.join(' '));
