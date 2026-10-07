import { openE, shotE, arg, sleep, report, waitForFlutter, URL0 } from './lib2.mjs';
// Tek tarayıcı örneği; konumlar ?scroll= ile yeniden yüklenerek alınır. Hareketi-azalt açık (belirleyici kareler).
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const list = arg(3, '0,0.95,1.95,2.95,3.95,4.95,5.95,6.9').split(',').map(Number);
const s = await openE({ browser, size, theme, scroll: list[0], reduce: true });
for (let i = 0; i < list.length; i++) {
  const sc = list[i];
  if (i > 0) { await s.page.goto(`${URL0}?theme=${theme}&scroll=${sc}`, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page, 90000); }
  await sleep(2200);
  console.log(await shotE(s, `tour_${String(sc).replace('.', '_')}`));
}
console.log(report(s));
await s.close();
