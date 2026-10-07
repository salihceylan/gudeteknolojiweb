import { connect, goto, shot, cdpDrag, cdpRelease, sleep, rep } from './lib.mjs';
const s = await connect();
await goto(s, 'http://localhost:8099/');
// p ~ 0.25 / 0.5 / 0.75 (D = 0.95*784 = 745 css px)
for (const [name, d] of [['a', 186], ['b', 372], ['c', 560], ['d', 700]]) {
  await goto(s, 'http://localhost:8099/');
  await cdpDrag(s, 206, 700, 700 - d, { steps: 20, hold: true });
  await sleep(1200);
  console.log(name, await shot(s, 'ir_' + name));
  await cdpRelease(s);
  await sleep(2500);
  console.log(name + 'after', await shot(s, 'ir_' + name + '_after'));
}
console.log(rep(s));
process.exit(0);
