import { launch, ready, sleep, URL0 } from './util.mjs';
const s = await launch();
const { page, log } = s;
let navs = 0;
page.on('framenavigated', (f) => { if (f === page.mainFrame()) navs++; });
const t0 = Date.now();
await page.goto(URL0, { waitUntil: 'load' });
await ready(page);
console.log('ready ms', Date.now() - t0);
await sleep(6000);
console.log('navigations', navs);
const info = await page.evaluate(async () => {
  const q = (s) => document.querySelector(s);
  const regs = await navigator.serviceWorker.getRegistrations();
  return {
    title: document.title, lang: document.documentElement.lang,
    desc: q('meta[name=description]')?.content, theme: q('meta[name=theme-color]')?.content, cs: q('meta[name=color-scheme]')?.content,
    dataTheme: document.documentElement.getAttribute('data-theme'),
    htmlBg: getComputedStyle(document.documentElement).backgroundColor, bodyBg: getComputedStyle(document.body).backgroundColor,
    regs: regs.length, scripts: [...document.scripts].map(s=>s.src), links: [...document.querySelectorAll('link')].map(l=>l.rel+' '+l.href),
    viewportMeta: q('meta[name=viewport]')?.content,
    bodyChildren: [...document.body.children].map(c=>c.tagName),
  };
});
console.log(JSON.stringify(info, null, 1));
console.log('errors', log.errors, 'warn', log.warnings, 'failed', log.failed);
const byType = {};
for (const r of log.reqs) { const u = new URL(r.url); console.log(r.status, r.len, r.fromSW, u.pathname); }
await s.close();
