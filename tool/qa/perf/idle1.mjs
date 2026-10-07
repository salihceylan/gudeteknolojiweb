import { launch, ready, sleep, URL0 } from './util.mjs';
const s = await launch();
const { page, ctx, log } = s;
const cdp0 = await ctx.newCDPSession(page);
const res = [];
for (const sc of [0, 1, 1.9, 2.6, 3.4, 4.2, 4.9, 5.7]) {
  await page.goto(URL0 + '?scroll=' + sc, { waitUntil: 'load', timeout: 90000 });
  await ready(page); await sleep(3500);
  const cdp = await ctx.newCDPSession(page);
  await cdp.send('Performance.enable');
  const m = async () => Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map((x) => [x.name, x.value]));
  const a = await m(); await sleep(4000); const b = await m();
  res.push(`scroll ${sc}: task ${(b.TaskDuration - a.TaskDuration).toFixed(2)}s script ${(b.ScriptDuration - a.ScriptDuration).toFixed(2)}s layouts ${b.LayoutCount - a.LayoutCount} frames~(recalc) ${b.RecalcStyleCount - a.RecalcStyleCount}`);
  console.log(res[res.length - 1]);
}
await s.close();
