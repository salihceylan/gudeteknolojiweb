import { launch, ready, sleep, URL0, shot, OUT } from './util.mjs';
import fs from 'node:fs';
const theme = process.argv[2] || 'dark';
const scrolls = (process.argv[3] || '0,1,1.9,2.6,3.4,4.2,4.9,5.7').split(',').map(Number);
const s = await launch({ colorScheme: theme });
const { page, log } = s;
const all = [];
for (const sc of scrolls) {
  await page.goto(URL0 + `?scroll=${sc}&theme=${theme}`, { waitUntil: 'load' });
  await ready(page); await sleep(3500);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForSelector('flt-semantics', { timeout: 8000 });
  await sleep(1500);
  const rects = await page.evaluate(() => [...document.querySelector('flt-semantics-host').querySelectorAll('*')]
    .filter((n) => !n.children.length && n.textContent.trim())
    .map((n) => { const r = n.getBoundingClientRect(); const pr = n.parentElement.getBoundingClientRect(); const rr = r.width ? r : pr; return { t: n.textContent.trim().split(String.fromCharCode(10))[0].slice(0, 50), x: rr.x, y: rr.y, w: rr.width, h: rr.height }; })
    .filter((r) => r.y > 70 && r.y + r.h <= innerHeight && r.w > 0));
  const f = await shot(page, `ct_${theme}_${sc}`);
  all.push({ scroll: sc, file: f, rects });
}
fs.writeFileSync(`${OUT}/ct_${theme}.json`, JSON.stringify(all));
console.log('done', all.map((a) => a.rects.length), log.errors);
await s.close();
