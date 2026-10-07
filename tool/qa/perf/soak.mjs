import { launch, ready, sleep, URL0, shot } from './util.mjs';
const cycles = +(process.argv[2] || 6);
const s = await launch({}, ['--enable-precise-memory-info', '--js-flags=--expose-gc']);
const { page, log, ctx } = s;
await page.addInitScript(() => {
  window.__lt = []; window.__cls = 0;
  try { new PerformanceObserver((l) => { for (const e of l.getEntries()) window.__lt.push([Math.round(e.startTime), Math.round(e.duration)]); }).observe({ type: 'longtask', buffered: true }); } catch {}
  try { new PerformanceObserver((l) => { for (const e of l.getEntries()) if (!e.hadRecentInput) window.__cls += e.value; }).observe({ type: 'layout-shift', buffered: true }); } catch {}
});
await page.goto(URL0, { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(3000);
const cdp = await ctx.newCDPSession(page);
await cdp.send('Performance.enable'); await cdp.send('HeapProfiler.enable');
const metric = async () => {
  await cdp.send('HeapProfiler.collectGarbage'); await cdp.send('HeapProfiler.collectGarbage');
  const h = await cdp.send('Runtime.getHeapUsage');
  const m = Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map((x) => [x.name, x.value]));
  const lt = await page.evaluate(() => ({ n: window.__lt.length, sum: window.__lt.reduce((a, b) => a + b[1], 0), max: Math.max(0, ...window.__lt.map((x) => x[1])), cls: window.__cls }));
  return { heapMB: +(h.usedSize / 1048576).toFixed(1), totalMB: +(h.totalSize / 1048576).toFixed(1), nodes: m.Nodes, listeners: m.JSEventListeners, task: +m.TaskDuration.toFixed(1), script: +m.ScriptDuration.toFixed(1), lt, wall: +(m.Timestamp).toFixed(0) };
};
const out = [];
out.push({ cycle: 0, ...(await metric()) });
console.log(JSON.stringify(out[0]));
const click = async (x, y) => { await page.mouse.move(x, y); await sleep(80); await page.mouse.down(); await sleep(50); await page.mouse.up(); };
for (let c = 1; c <= cycles; c++) {
  await page.mouse.move(720, 450);
  for (let i = 0; i < 9; i++) { for (let k = 0; k < 6; k++) { await page.mouse.wheel(0, 100); await sleep(16); } await sleep(550); }
  await click(727, 29); await sleep(2500);        // Kamera
  for (let d = 0; d < 3; d++) { await page.mouse.move(1000, 420); await page.mouse.down(); for (let i = 1; i <= 10; i++) { await page.mouse.move(1000 - i * 40 * (d % 2 ? -1 : 1), 420); await sleep(30); } await page.mouse.up(); await sleep(900); }
  for (let t = 0; t < 2; t++) { await click(1340, 32); await sleep(1400); }
  for (let t = 0; t < 2; t++) { await click(1388, 32); await sleep(1500); await click(1388, 32); await sleep(1300); }
  for (let i = 0; i < 6; i++) { for (let k = 0; k < 6; k++) { await page.mouse.wheel(0, -160); await sleep(16); } await sleep(450); }
  await click(75, 32); await sleep(2200);        // logo -> top
  const m = await metric(); out.push({ cycle: c, ...m }); console.log(JSON.stringify(m));
}
console.log('errors', log.errors.slice(0, 5), 'warn', log.warnings.slice(0, 5));
await s.close();
