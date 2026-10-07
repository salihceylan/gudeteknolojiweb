import { openE, shotE, arg, sleep, report } from './lib2.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark'), reduce = arg(3, '1') === '1';
const list = (arg(4, '0,0.5,0.95,1.95,2.95,3.95,4.95,5.95,6.9')).split(',').map(Number);
for (const sc of list) {
  const s = await openE({ browser, size, theme, scroll: sc, reduce });
  await sleep(2500);
  console.log(await shotE(s, `tour_${String(sc).replace('.', '_')}`), 'loadMs', s.loadMs);
  if (s.errors.length || s.failedRequests.length) console.log(report(s));
  await s.close();
}
