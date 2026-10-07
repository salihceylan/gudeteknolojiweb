import { openE, shotE, arg, sleep, report, collectLabelBoxes, tap, waitForFlutter, URL0 } from './lib2.mjs';
import { readNodes } from './probe.mjs';
import { installLinkHook, links } from './hook.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const s = await openE({ browser, size, theme, pre: installLinkHook });
await sleep(1500);
const center = (b) => [b.x + b.width / 2, b.y + b.height / 2];
const clickAndLinks = async (name, x, y) => { await tap(s, x, y); await sleep(700); const l = await links(s); console.log(name, JSON.stringify(l)); await s.page.evaluate(() => (window.__links = [])); };
// 1) üst çubuk Teklif Pro
let boxes = await collectLabelBoxes(s);
const tp = boxes.find((b) => b.role === 'button' && b.label === 'Teklif Pro' && b.y < 70);
console.log('topbar Teklif Pro box', JSON.stringify(tp));
await clickAndLinks('topbar Teklif Pro', ...center(tp));
console.log('pages after', s.ctx.pages().length);
// 2) panel (menu=1)
await s.page.goto(`${URL0}?theme=${theme}&menu=1`, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page); await sleep(2500);
const nodes = await readNodes(s);
const pick = (t, n = 0) => nodes.filter((x) => x.label.includes(t) && x.x > 500)[n];
const panel = { tp: nodes.filter((x) => x.label === 'Teklif Pro').pop(), phone: pick('543'), mail: pick('@gudeteknoloji'), wa: nodes.filter((x) => x.label === 'WhatsApp').pop() };
console.log('panel nodes', JSON.stringify(panel));
console.log('panel all', nodes.filter((x) => x.x > (s.page.viewportSize().width - 450)).map((x) => `${x.label.slice(0, 30)}@${x.x},${x.y} ${x.w}x${x.h}`).join(' | '));
await s.page.goto(`${URL0}?theme=${theme}&menu=1`, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page); await sleep(2500);
await s.page.evaluate(() => (window.__links = []));
for (const k of ['tp', 'phone', 'mail', 'wa']) { const b = panel[k]; if (!b) { console.log('missing', k); continue; } await tap(s, b.x + b.w / 2, b.y + b.h / 2); await sleep(700); console.log('panel', k, JSON.stringify(await links(s))); await s.page.evaluate(() => (window.__links = [])); }
console.log(await shotE(s, 'panel_after_links'));
// 3) iletişim sahnesi
const at = 8;
await s.page.goto(`${URL0}?theme=${theme}&scroll=${at}`, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page); await sleep(2500);
const n2 = await readNodes(s);
const c = { wa: n2.find((x) => x.label.includes("WhatsApp'tan")), phone: n2.find((x) => x.label.startsWith('Telefon')), mail: n2.find((x) => x.label.startsWith('E-Posta')), tek: n2.filter((x) => x.label === 'Teklif Pro' || x.label.startsWith('Teklif Pro')) };
console.log('contact nodes', JSON.stringify(c));
await s.page.goto(`${URL0}?theme=${theme}&scroll=${at}`, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page); await sleep(2500);
await s.page.evaluate(() => (window.__links = []));
for (const k of ['wa', 'phone', 'mail']) { const b = c[k]; if (!b) { console.log('missing', k); continue; } await tap(s, b.x + b.w / 2, b.y + b.h / 2); await sleep(700); console.log('contact', k, JSON.stringify(await links(s))); await s.page.evaluate(() => (window.__links = [])); }
// 4) Teklif bandı düğmesi
const tb = c.tek.find((x) => x.role === 'button' && x.y > 60);
if (tb) { await tap(s, tb.x + tb.w / 2, tb.y + tb.h / 2); await sleep(700); console.log('band teklif', JSON.stringify(await links(s))); }
console.log(await shotE(s, 'contact_end'));
console.log('pages', s.ctx.pages().length);
console.log(report(s));
await s.close();
