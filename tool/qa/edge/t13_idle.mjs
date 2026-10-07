import { openE, shotE, arg, sleep, report, waitForFlutter, URL0 } from './lib2.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440');
const s = await openE({ browser, size, theme: 'dark' });
const cdp = await s.ctx.newCDPSession(s.page);
await cdp.send('Performance.enable');
const get = async () => Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map((m) => [m.name, m.value]));
const pts = [0, 0.95, 1.95, 2.85, 3.9, 4.9, 5.9, 8];
for (const sc of pts) {
  await s.page.goto(`${URL0}?theme=dark&scroll=${sc}`, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page, 90000);
  await cdp.send('Performance.enable');
  await s.page.mouse.move(5, 880);
  await sleep(3500);
  const a = await get(); await sleep(4000); const b = await get();
  const d = (k) => +(b[k] - a[k]).toFixed(3);
  console.log(`scroll ${sc}: task ${d('TaskDuration')}s script ${d('ScriptDuration')}s layout ${d('LayoutDuration')}s recalc ${d('RecalcStyleDuration')}s heapMB ${(b.JSHeapUsedSize / 1e6).toFixed(1)}`);
}
console.log(report(s));
await s.close();
