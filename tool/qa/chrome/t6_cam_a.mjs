import { open, shot, sleep, report, startCast } from './common.mjs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th, scroll: 0.95 });
await sleep(3500);
const P = s.page;
console.log('home', await shot(s, 't6a_home'));
// fling: hızlı sürükle + bırak
await P.mouse.move(900, 450); await P.mouse.down();
for (let i = 1; i <= 10; i++) { await P.mouse.move(900 + i * 30, 450); await sleep(16); }
console.log('dragging', await shot(s, 't6a_dragging_hold'));
const cast = await startCast(s, 'cam_return_' + th, { quality: 60 });
await P.mouse.move(1230, 450); await P.mouse.up();
const tUp = Date.now() - cast.t0;
await sleep(7000);
const fr = await cast.stop();
console.log('release at', tUp, 'frames', fr.length, 'last t', fr.at(-1)?.t);
console.log('after', await shot(s, 't6a_after_return'));
// dikey sürükleme
await P.mouse.move(900, 400); await P.mouse.down();
for (let i = 1; i <= 10; i++) { await P.mouse.move(900, 400 + i * 30); await sleep(16); }
await P.mouse.up(); await sleep(2500);
console.log('vertical drag', await shot(s, 't6a_vertical'));
// klavye
await P.mouse.move(900, 450); await P.mouse.down(); await P.mouse.up(); await sleep(300);
for (let i = 0; i < 4; i++) { await P.keyboard.press('ArrowLeft'); await sleep(120); }
await sleep(1500); console.log('key left x4', await shot(s, 't6a_key_left4'));
for (let i = 0; i < 8; i++) { await P.keyboard.press('ArrowRight'); await sleep(120); }
await sleep(1500); console.log('key right x8', await shot(s, 't6a_key_right8'));
await sleep(4000); console.log('key after settle', await shot(s, 't6a_key_settle'));
console.log(report(s));
await s.close();
