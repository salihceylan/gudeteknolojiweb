import { connect, shot, swipeCss, sleep, rep, measureFrames } from './lib.mjs';
const s = await connect();
await shot(s, 's1_00');
for (let i = 1; i <= 6; i++) {
  swipeCss(206, 650, 206, 150, 700);
  await sleep(2200);
  console.log(i, await shot(s, 's1_' + String(i).padStart(2, '0')));
}
console.log(rep(s));
process.exit(0);
