import { openE, shotE, arg, sleep, report, measureFrames } from './lib2.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const s = await openE({ browser, size, theme, scroll: 0.95 });
await sleep(3000);
const vp = s.page.viewportSize();
const m = s.page.mouse;
const cx = vp.width * 0.65, cy = vp.height * 0.5;
console.log('0 home', await shotE(s, 'cam_0_home'));
// yatay sürükleme: sola 320px, ~0.5 sn
await m.move(cx, cy); await sleep(150); await m.down();
for (let i = 1; i <= 16; i++) { await m.move(cx - i * 20, cy + (i % 2)); await sleep(30); }
console.log('1 dragging (hold)', await shotE(s, 'cam_1_hold'));
await m.up();
await sleep(250);
console.log('2 +250ms release', await shotE(s, 'cam_2_rel250'));
await sleep(900);
console.log('3 +1.2s', await shotE(s, 'cam_3_rel1200'));
await sleep(3500);
console.log('4 settled', await shotE(s, 'cam_4_settled'));
// sağa uzun sürükleme ve bırakma: 720px
await m.move(cx - 300, cy); await m.down();
for (let i = 1; i <= 30; i++) { await m.move(cx - 300 + i * 24, cy); await sleep(16); }
await m.up(); await sleep(400);
console.log('5 fast right release', await shotE(s, 'cam_5_fastright'));
await sleep(4500);
console.log('6 settled2', await shotE(s, 'cam_6_settled2'));
// dikey sürükleme (fare): sayfa kaymamalı/kamera dönmemeli?
await m.move(cx, cy); await m.down();
for (let i = 1; i <= 15; i++) { await m.move(cx + (i % 2), cy - i * 20); await sleep(30); }
await m.up(); await sleep(2500);
console.log('7 vertical drag mouse', await shotE(s, 'cam_7_vertical'));
// klavye: odak + ok tuşu
await s.page.mouse.click(cx, cy); await sleep(300);
await s.page.keyboard.press('ArrowLeft'); await s.page.keyboard.press('ArrowLeft'); await sleep(700);
console.log('8 key left x2', await shotE(s, 'cam_8_keys'));
await sleep(4000);
console.log('9 key settled', await shotE(s, 'cam_9_keys_settled'));
console.log(JSON.stringify(await measureFrames(s, 1500)));
console.log(report(s));
await s.close();
