import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page, log } = s;
const isOpen = async (tag) => { const f = await shot(page, 'esc_' + tag, { clip: { x: 1000, y: 100, width: 440, height: 300 } }); return f; };
await page.goto(URL0, { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(2500);
const files = [];
// A: mouse open, Esc
await page.mouse.move(1388, 32); await sleep(100); await page.mouse.down(); await page.mouse.up(); await sleep(2200);
files.push(await isOpen('A_open'));
await page.keyboard.press('Escape'); await sleep(2000);
files.push(await isOpen('A_afterEsc'));
// B: keyboard open (Tab x10 + Enter), immediately Esc
await page.goto(URL0, { waitUntil: 'load', timeout: 90000 }); await ready(page); await sleep(2500);
for (let i = 0; i < 10; i++) { await page.keyboard.press('Tab'); await sleep(120); }
await page.keyboard.press('Enter'); await sleep(2200);
files.push(await isOpen('B_open'));
await page.keyboard.press('Escape'); await sleep(2000);
files.push(await isOpen('B_afterEsc'));
// C: mouse open then Tab 1
await page.goto(URL0, { waitUntil: 'load', timeout: 90000 }); await ready(page); await sleep(2500);
await page.mouse.move(1388, 32); await sleep(100); await page.mouse.down(); await page.mouse.up(); await sleep(2200);
await page.keyboard.press('Tab'); await sleep(800);
files.push(await shot(page, 'esc_C_tab1_after_mouse_open'));
console.log(log.errors);
await s.close();
