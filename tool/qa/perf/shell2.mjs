import { launch, ready, sleep, URL0 } from './util.mjs';
const s = await launch();
const { page, log } = s;
page.on('framenavigated', (f) => { if (f === page.mainFrame()) console.log('nav', f.url()); });
await page.addInitScript(() => {
  new MutationObserver((m) => { for (const r of m) if (r.attributeName === 'lang') console.log('LANG CHANGED ->', document.documentElement.lang, performance.now()|0); }).observe(document.documentElement, { attributes: true });
});
page.on('console', (m) => console.log('  console:', m.text()));
await page.goto(URL0, { waitUntil: 'load' });
await ready(page);
await sleep(4000);
for (const r of log.reqs) console.log(r.status, r.len, r.url);
console.log(await page.evaluate(() => [location.href, document.documentElement.lang, document.querySelector('flutter-view')?.getAttribute('lang'), [...document.querySelectorAll('[lang]')].map(e=>e.tagName+':'+e.lang)]));
await s.close();
