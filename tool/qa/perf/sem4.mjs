import { launch, ready, sleep, URL0 } from './util.mjs';
const s = await launch();
const { page, log } = s;
for (const sc of [0, 2.5, 3.5, 4.5, 5.6]) {
  await page.goto(URL0 + '?scroll=' + sc, { waitUntil: 'load' });
  await ready(page); await sleep(2500);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForSelector('flt-semantics', { timeout: 8000 });
  await sleep(1800);
  const r = await page.evaluate(() => ({
    nodes: document.querySelectorAll('flt-semantics').length,
    headings: [...document.querySelectorAll('h1,h2,h3,h4,h5,h6')].map(e => e.tagName + ':' + e.textContent.slice(0, 40)),
    texts: [...document.querySelectorAll('flt-semantics')].filter(n => !n.children.length && n.textContent.trim()).map(n => n.textContent.trim().replace(/\n/g,' / ').slice(0, 45) + ' @' + Math.round(n.getBoundingClientRect().y)),
  }));
  console.log('=== scroll', sc, 'nodes', r.nodes, JSON.stringify(r.headings));
  console.log(r.texts.slice(0, 60).join('\n'));
}
await s.close();
