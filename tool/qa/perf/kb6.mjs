import { launch, ready, sleep, URL0, shot } from './util.mjs';
const theme = process.argv[2] || 'dark';
const s = await launch({ colorScheme: theme });
const { page, log } = s;
await page.goto(URL0 + '?theme=' + theme, { waitUntil: 'load' });
await ready(page); await sleep(2500);
await page.mouse.move(700, 450);
for (let i = 0; i < 10; i++) { await page.keyboard.press('Tab'); await sleep(150); }
await page.keyboard.press('Space'); await sleep(2200);
for (let i = 1; i <= 7; i++) { await page.keyboard.press('Tab'); await sleep(150); }
const files = [];
for (let i = 8; i <= 17; i++) { await page.keyboard.press('Tab'); await sleep(900); files.push(await shot(page, `kb6_${theme}_t${i}`, { clip: { x: 0, y: 0, width: 1440, height: 900 } })); }
console.log(files.length, log.errors);
await s.close();
