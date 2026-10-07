import { openE, shotE, arg, sleep, report, measureFrames } from './lib2.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const s = await openE({ browser, size, theme });
await sleep(2000);
const vp = s.page.viewportSize();
await s.page.mouse.move(vp.width / 2, vp.height / 2);
const wheel = async (dy, n = 1, gap = 40) => { for (let i = 0; i < n; i++) { await s.page.mouse.wheel(0, dy); await sleep(gap); } };
// 1) 3 çentik aşağı (360px) -> kamera sahnesine yerleşmeli
await wheel(120, 3); await sleep(2800);
console.log('A 360px down', await shotE(s, 'wheel_A_360down'));
// 2) 2 çentik yukarı -> açılışa dönmeli (yönlü mıknatıs)
await wheel(-120, 2); await sleep(2800);
console.log('B 240px up', await shotE(s, 'wheel_B_240up'));
// 3) 1 çentik aşağı (120px) -> ?
await wheel(120, 1); await sleep(2800);
console.log('C 120px down', await shotE(s, 'wheel_C_120down'));
// 4) 7 çentik hızlı
await wheel(120, 7, 20); await sleep(3000);
console.log('D +840px', await shotE(s, 'wheel_D_840'));
// 5) kararlılık: 2 sn arayla iki görüntü
const f1 = await shotE(s, 'wheel_D_stab1'); await sleep(2000); const f2 = await shotE(s, 'wheel_D_stab2');
console.log('stab', f1, f2);
// 6) fps
console.log(JSON.stringify(await measureFrames(s, 2000)));
console.log(report(s));
await s.close();
