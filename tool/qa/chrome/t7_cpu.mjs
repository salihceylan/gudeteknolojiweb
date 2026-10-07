import { open, shot, sleep, report, tap } from './common.mjs';
const th = process.argv[2] || 'dark';
const cycles = +(process.argv[3] || 1);
const s = await open({ theme: th });
await sleep(2000);
const P = s.page; await P.mouse.move(700, 450);
const cdp = await s.ctx.newCDPSession(P);
await cdp.send('Performance.enable');
const get = async () => Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map((m) => [m.name, m.value]));
const nav = [['hero', null], ['Kamera', [755, 29]], ['Urunler', [827, 29]], ['screen', 'wheel'], ['Hizmetler', [907, 29]], ['Surec', [981, 29]], ['Referanslar', [1061, 29]], ['Iletisim', [1146, 29]]];
for (let c = 0; c < cycles; c++) for (const [name, pos] of nav) {
  if (name === 'hero') { await tap(s, 72, 31); }
  else if (pos === 'wheel') { await P.mouse.wheel(0, 130); } else if (pos) { await tap(s, pos[0], pos[1]); await P.mouse.move(700, 300); }
  await sleep(3500);
  const a = await get(); await sleep(4000); const b = await get();
  const cpu = ((b.TaskDuration - a.TaskDuration) / 4 * 100).toFixed(0);
  const scr = ((b.ScriptDuration - a.ScriptDuration) / 4 * 100).toFixed(0);
  console.log(`c${c} ${name}: task ${cpu}% script ${scr}% heapUsed ${(b.JSHeapUsedSize / 1e6).toFixed(1)}MB heapTotal ${(b.JSHeapTotalSize / 1e6).toFixed(1)}MB nodes ${b.Nodes} docs ${b.Documents}`);
}
console.log(report(s));
await s.close();
