import { connect, shot, swipeCss, tapCss, sleep, goto, cdpDrag, cdpRelease } from './lib.mjs';
const s = await connect();
await goto(s, 'http://localhost:8099/');
for (let i = 0; i < 5; i++) { swipeCss(206, 650, 206, 150, 700); await sleep(2300); }
console.log(await shot(s, 'dv_0'));
tapCss(205, 442); await sleep(700);
console.log(await shot(s, 'dv_1'));
await sleep(1500);
console.log(await shot(s, 'dv_2'));
await sleep(3000);
console.log(await shot(s, 'dv_3'));
// dikey kaydırma cihaz üzerinde sayfayi kaydirmali
swipeCss(205, 500, 205, 250, 500); await sleep(2500);
console.log(await shot(s, 'dv_4'));
process.exit(0);
