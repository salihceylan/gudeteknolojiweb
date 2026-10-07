import { launch, ready, sleep, URL0 } from './util.mjs';
const s = await launch();
const { page } = s;
await page.goto(URL0 + '?scroll=2.6', { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(3000);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForSelector('flt-semantics'); await sleep(1500);
const read = () => page.evaluate(() => { const n = [...document.querySelectorAll('flt-semantics')].find(x => /AHBU Akıllı Kapı Kontrol cihazı/.test(x.getAttribute('aria-label') || '')); return n ? [n.getAttribute('role'), n.getAttribute('aria-label'), n.getAttribute('aria-valuenow'), n.getAttribute('aria-valuemax')] : null; });
for (let i = 0; i < 3; i++) { console.log(JSON.stringify(await read())); await sleep(3000); }
const live = await page.evaluate(() => document.querySelector('flt-announcement-polite')?.textContent);
console.log('announce:', live);
await s.close();
