import { openE, shotE, arg, sleep, report } from './lib2.mjs';
const browser = arg(0, 'edge');
const sizes = arg(1, 'd1440,d1024').split(','), themes = arg(2, 'dark,light').split(',');
const list = arg(3, '0,0.5,0.95,1.95,2.95,3.95,4.95,5.95,6.9').split(',').map(Number);
const prefix = arg(4, 'tour');
for (const theme of themes) for (const size of sizes) for (const sc of list) {
  const s = await openE({ browser, size, theme, scroll: sc, reduce: true });
  await sleep(2500);
  console.log(await shotE(s, `${prefix}_${String(sc).replace('.', '_')}`), 'loadMs', s.loadMs);
  if (s.errors.length || s.failedRequests.length) console.log(report(s));
  await s.close();
}
