import { launch, ready, sleep, URL0, shot } from './util.mjs';
const [w, h] = process.argv.slice(2).map(Number);
const s = await launch({ viewport: { width: w, height: h } });
const { page, log } = s;
await page.goto(URL0 + '?menu=1', { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(3500);
const a = await shot(page, `panel_${w}x${h}_a`);
await page.mouse.move(w - 100, h / 2);
for (let i = 0; i < 8; i++) { await page.mouse.wheel(0, 120); await sleep(30); }
await sleep(1200);
const b = await shot(page, `panel_${w}x${h}_b`);
console.log(a, b, log.errors);
await s.close();
