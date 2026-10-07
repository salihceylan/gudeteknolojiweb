import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page } = s;
await page.goto(URL0 + '?scroll=1', { waitUntil: 'load' });
await ready(page); await sleep(3000);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForSelector('flt-semantics');
for (const w of [500, 6000]) {
  await sleep(w);
  const r = await page.evaluate(() => [...document.querySelector('flt-semantics-host').querySelectorAll('*')].filter(n => !n.children.length && /Her açıdan|KAMERA S|Ağ altyap/.test(n.textContent)).map(n => { const r = n.getBoundingClientRect(); const p = n.parentElement.getBoundingClientRect(); return [n.textContent.slice(0,20), Math.round(r.y), Math.round(r.height), 'parent', Math.round(p.y), Math.round(p.height)]; }));
  console.log(w, JSON.stringify(r));
}
await shot(page, 'semrect');
await s.close();
