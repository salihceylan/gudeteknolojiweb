import { openE, shotE, arg, sleep, report, tap, waitForFlutter, URL0 } from './lib2.mjs';
import { readNodes } from './probe.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const s = await openE({ browser, size, theme, scroll: 8 });
// dış ağı kes: gerçek gezinti yapılmasın
const seen = new Set(); await s.ctx.route((u) => { seen.add(u.host); return !/^(localhost|www\.gstatic\.com|fonts\.gstatic\.com|fonts\.googleapis\.com)/.test(u.host); }, (r) => r.abort());
await sleep(2500);
const nodes = await readNodes(s);
console.log(nodes.filter((n) => n.y > 300 && n.x < 1400).map((x) => `${x.role}|${x.label.slice(0, 40)}@${x.x},${x.y} ${x.w}x${x.h}`).join('\n'));
await s.page.goto(`${URL0}?theme=${theme}&scroll=8`, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page); await sleep(2500);
const evs = [];
s.ctx.on('page', (p) => evs.push('new page ' + p.url()));
s.page.on('popup', (p) => evs.push('popup ' + p.url()));
s.page.on('framenavigated', (f) => { if (f === s.page.mainFrame()) evs.push('main nav ' + f.url()); });
const targets = { Telefon: { x: 1000, y: 478, w: 1, h: 1 }, 'E-Posta': { x: 1000, y: 565, w: 1, h: 1 }, "WhatsApp'tan": nodes.find((x) => x.label.includes("WhatsApp'tan")) };
for (const lab of Object.keys(targets)) {
  const n = targets[lab];
  if (!n) { console.log('missing', lab); continue; }
  evs.length = 0;
  await tap(s, n.x + n.w / 2, n.y + n.h / 2); await sleep(2500);
  console.log(lab, 'events:', JSON.stringify(evs), 'pages:', JSON.stringify(s.ctx.pages().map((p) => p.url())));
  for (const p of s.ctx.pages()) if (p !== s.page) await p.close().catch(() => {});
}
console.log("hosts", [...seen].join(",")); console.log(report(s));
await s.close();
