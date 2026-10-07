import { openE, arg, sleep, report } from './lib2.mjs';
const s = await openE({ browser: 'edge', size: 'd1440', theme: 'dark' });
const cdp = await s.ctx.newCDPSession(s.page);
await cdp.send('Performance.enable'); await cdp.send('HeapProfiler.enable');
const heap = async () => { await cdp.send('HeapProfiler.collectGarbage'); const m = (await cdp.send('Performance.getMetrics')).metrics; const g = (n) => m.find((x) => x.name === n).value; return { js: +(g('JSHeapUsedSize') / 1e6).toFixed(1), nodes: g('Nodes'), listeners: g('JSEventListeners') }; };
await s.page.mouse.move(720, 450);
console.log('start', JSON.stringify(await heap()));
for (let c = 1; c <= 4; c++) {
  for (let i = 0; i < 18; i++) { await s.page.mouse.wheel(0, 400); await sleep(60); }
  await sleep(2500);
  for (let i = 0; i < 18; i++) { await s.page.mouse.wheel(0, -400); await sleep(60); }
  await sleep(2500);
  console.log('cycle', c, JSON.stringify(await heap()));
}
console.log(report(s));
await s.close();
