import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page, log } = s;
await page.goto(URL0, { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(2500);
for (let i = 0; i < 13; i++) { await page.keyboard.press('Tab'); await sleep(200); }
await sleep(1500);
const files = [await shot(page, 'kb11_0')];
for (const k of ['PageDown', 'PageDown', 'PageDown', 'End', 'Home']) { await page.keyboard.press(k); await sleep(2300); files.push(await shot(page, `kb11_${files.length}_${k}`)); }
console.log(log.errors);
await s.close();
