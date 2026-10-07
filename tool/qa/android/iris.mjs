import { connect, goto, shot, swipeCss, sleep, rep, measureFrames } from './lib.mjs';
const s = await connect();
await goto(s, 'http://localhost:8099/');
console.log('top', await shot(s, 'i_00'));
for (let i = 1; i <= 7; i++) {
  swipeCss(206, 500, 206, 500 - 130, 500); // yavas, kisa
  await sleep(1800);
  console.log(i, await shot(s, 'i_' + String(i).padStart(2, '0')));
}
console.log(rep(s));
process.exit(0);
