import { connect, goto, shot, cdpDrag, cdpRelease, swipeCss, sleep, rep, screencap } from './lib.mjs';
const s = await connect();
await goto(s, 'http://localhost:8099/?scroll=0.95');
await sleep(1500);
console.log('base', await shot(s, 'c_00'));
// adb ile gerçek parmak: yatay sürükleme (kamera üzerinde), bırak
swipeCss(60, 420, 340, 430, 600); await sleep(300);
console.log('h-adb-mid', await shot(s, 'c_01'));
await sleep(2500);
console.log('h-adb-after', await shot(s, 'c_02'));
// CDP tutarak yatay 150px
await cdpDrag(s, 100, 420, 425, { dx: 200, steps: 15, hold: true }); await sleep(800);
console.log('h-hold', await shot(s, 'c_03'));
await cdpRelease(s); await sleep(3000);
console.log('h-release', await shot(s, 'c_04'));
// dikey: kamera üzerinde dikey sürükleme sayfayı kaydırmalı
swipeCss(206, 500, 206, 250, 500); await sleep(2500);
console.log('v-after', await shot(s, 'c_05'));
console.log(rep(s));
process.exit(0);
