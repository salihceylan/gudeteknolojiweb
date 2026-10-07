import { openE, shotE, arg, sleep, report } from './lib2.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440t'), theme = arg(2, 'dark');
const s = await openE({ browser, size, theme, scroll: 0.95 });
await sleep(3000);
const vp = s.page.viewportSize();
const cdp = await s.ctx.newCDPSession(s.page);
const swipe = async (x0, y0, x1, y1, steps = 14, dt = 16) => {
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: x0, y: y0 }] });
  for (let i = 1; i <= steps; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x0 + (x1 - x0) * i / steps, y: y0 + (y1 - y0) * i / steps }] }); await sleep(dt); }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
};
const cx = vp.width * 0.65, cy = vp.height * 0.5;
console.log('0', await shotE(s, 'touch_0_home'));
await swipe(cx + 150, cy, cx - 150, cy); await sleep(300);
console.log('1 horizontal swipe +300ms', await shotE(s, 'touch_1_hswipe'));
await sleep(4000);
console.log('2 settled', await shotE(s, 'touch_2_settled'));
// dikey kaydırma: kamera üzerinde yukarı swipe -> sayfa kaymalı (ürünler sahnesine), kamera dönmemeli
await swipe(cx, cy + 150, cx, cy - 150); await sleep(3000);
console.log('3 vertical swipe (should scroll page)', await shotE(s, 'touch_3_vswipe'));
// çapraz (çoğunlukla dikey)
await swipe(cx - 20, cy + 200, cx + 40, cy - 150); await sleep(3000);
console.log('4 mostly-vertical swipe', await shotE(s, 'touch_4_diag'));
console.log(report(s));
await s.close();
