import { launch, ready, sleep, URL0 } from './util.mjs';
import fs from 'node:fs';
const q = process.argv[2] || '';
const s = await launch();
const { page, log } = s;
await page.goto(URL0 + q, { waitUntil: 'load' });
await ready(page); await sleep(2500);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForSelector('flt-semantics', { timeout: 8000 });
await sleep(1500);
const tree = await page.evaluate(() => {
  const out = [];
  const walk = (n, d) => {
    if (n.tagName === 'FLT-SEMANTICS') {
      const r = n.getBoundingClientRect();
      const own = [...n.childNodes].filter((c) => c.nodeType === 3).map((c) => c.textContent).join('|');
      out.push({ d, role: n.getAttribute('role'), aria: n.getAttribute('aria-label'), text: own, tabindex: n.getAttribute('tabindex'), level: n.getAttribute('aria-level'), hidden: n.getAttribute('aria-hidden'), flt: n.id, x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height), checked: n.getAttribute('aria-selected'), expanded: n.getAttribute('aria-expanded'), disabled: n.getAttribute('aria-disabled') });
    }
    for (const c of n.children) walk(c, d + 1);
  };
  const host = document.querySelector('flt-semantics-host') || document.body;
  walk(host, 0);
  return out;
});
fs.writeFileSync('../../qa_out/perf/sem_tree.json', JSON.stringify(tree, null, 1));
for (const n of tree) console.log('  '.repeat(Math.min(n.d, 8)) + `[${n.role || '-'}] ${n.aria ?? ''} ${n.text ? '«' + n.text + '»' : ''} ti=${n.tabindex} (${n.x},${n.y} ${n.w}x${n.h})`);
const heads = await page.evaluate(() => [...document.querySelectorAll('h1,h2,h3,h4,[role=heading]')].map((e) => e.tagName + ':' + (e.getAttribute('aria-level') || '') + ':' + e.textContent.slice(0, 40)));
console.log('headings', heads);
console.log(log.errors);
await s.close();
