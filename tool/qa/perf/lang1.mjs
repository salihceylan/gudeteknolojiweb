import { launch, sleep, URL0 } from './util.mjs';
const s = await launch();
const { page } = s;
await page.addInitScript(() => { window.__langs = []; let last = null; const t = setInterval(() => { const l = document.documentElement && document.documentElement.lang; if (l !== last) { last = l; window.__langs.push([Math.round(performance.now()), l]); } }, 20); });
await page.goto(URL0, { waitUntil: 'load', timeout: 90000 });
await sleep(6000);
console.log(JSON.stringify(await page.evaluate(() => window.__langs)));
await s.close();
