import { launch, ready, sleep, URL0 } from './util.mjs';
const s = await launch();
const { page, log } = s;
await page.goto(URL0, { waitUntil: 'load' });
await ready(page); await sleep(3000);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForSelector('flt-semantics', { timeout: 8000 });
await sleep(2000);
console.log(await page.evaluate(() => {
  const b = [...document.querySelectorAll('flt-semantics[role=button]')].find(x => x.textContent.includes('Ürünler'));
  return b.outerHTML;
}));
console.log(await page.evaluate(() => { const b = [...document.querySelectorAll('flt-semantics')].find(x => x.textContent.includes('Gelecek sizin') && !x.children.length); return b?.outerHTML; }));
console.log(await page.evaluate(() => [...document.querySelectorAll('flt-semantics-placeholder, flt-announcement-host, p')].map(e => e.outerHTML.slice(0,300))));
await s.close();
