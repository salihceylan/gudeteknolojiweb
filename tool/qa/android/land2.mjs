import { connect, geom, shot, cdpDrag, sleep, rep, goto } from './lib.mjs';
const s = await connect();
const g = await geom(s);
// logoya CDP dokunuşu yerine adb: landscape'te CSS->ekran çevirimi karışık; sayfayı yeniden yükle
await sleep(2000);
console.log('top', await shot(s, 'ls2_00'));
for (let i = 1; i <= 8; i++) {
  await cdpDrag(s, g.iw / 2, 270, 270 - 200, { steps: 14, stepMs: 30 });
  await sleep(3500);
  console.log(i, await shot(s, 'ls2_0' + i));
}
console.log(rep(s));
process.exit(0);
