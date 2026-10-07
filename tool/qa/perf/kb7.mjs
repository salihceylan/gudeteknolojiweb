import { launch, ready, sleep, URL0, shot } from './util.mjs';
const theme = process.argv[2] || 'dark';
const s = await launch({ colorScheme: theme });
const { page, log } = s;
await page.goto(URL0 + '?scroll=1&theme=' + theme, { waitUntil: 'load' });
await ready(page); await sleep(3500);
await page.mouse.move(100, 800);
const files = [await shot(page, `kb7_${theme}_start`)];
for (let i = 1; i <= 11; i++) { await page.keyboard.press('Tab'); await sleep(300); }
await sleep(1500);
files.push(await shot(page, `kb7_${theme}_tab11`));
for (let i = 0; i < 4; i++) { await page.keyboard.press('ArrowRight'); await sleep(150); }
await sleep(1200);
files.push(await shot(page, `kb7_${theme}_right4`));
for (let i = 0; i < 12; i++) { await page.keyboard.press('ArrowLeft'); await sleep(100); }
await sleep(1200);
files.push(await shot(page, `kb7_${theme}_left12`));
await page.keyboard.press('Tab'); await sleep(1800);
files.push(await shot(page, `kb7_${theme}_tab12`));
await page.keyboard.press('PageDown'); await sleep(2200);
files.push(await shot(page, `kb7_${theme}_pgdn`));
console.log(files.length, log.errors);
await s.close();
