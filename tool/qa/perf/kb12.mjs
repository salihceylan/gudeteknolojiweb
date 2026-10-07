import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page, log, ctx } = s;
await page.addInitScript(() => { window.__opens = []; window.open = function (...a) { window.__opens.push(a.slice(0, 2)); return null; }; });
await page.goto(URL0, { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(2500);
for (let i = 0; i < 10; i++) { await page.keyboard.press('Tab'); await sleep(120); }
await page.keyboard.press('Enter'); await sleep(2200);
await page.keyboard.down('Shift');
await page.keyboard.press('Tab'); await sleep(500);   // theme button
await page.keyboard.press('Tab'); await sleep(500);   // teklif pro (hidden)
await page.keyboard.up('Shift');
console.log(await shot(page, 'kb12_shifttab2', { clip: { x: 600, y: 0, width: 840, height: 80 } }));
await page.keyboard.press('Enter'); await sleep(1200);
console.log('opens after Enter on hidden-focused item:', JSON.stringify(await page.evaluate(() => window.__opens)));
await s.close();
