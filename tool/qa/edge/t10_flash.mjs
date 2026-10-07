import { openE, shotE, arg, sleep, report, URL0 } from './lib2.mjs';
const browser = arg(0, 'edge');
const s = await openE({ browser, size: 'd1440', theme: 'light' });
await sleep(1000);
console.log(await s.page.evaluate(() => localStorage.getItem('gude-theme')));
// Açık tema kayıtlı; yeniden yükle ve erken kareleri yakala
await s.page.goto(URL0, { waitUntil: 'commit' });
const t0 = Date.now(); let i = 0;
while (Date.now() - t0 < 14000 && i < 8) {
  const info = await s.page.evaluate(() => ({ boot: !!document.getElementById('boot'), bootOp: document.getElementById('boot')?.style.opacity, pane: !!document.querySelector('flt-glass-pane'), bodyBg: getComputedStyle(document.body).backgroundColor, dt: document.documentElement.getAttribute('data-theme') })).catch(() => null);
  const f = await shotE(s, `flash_${i}`).catch(() => null);
  console.log(i, Date.now() - t0, JSON.stringify(info));
  i++; await sleep(500);
}
await s.close();
