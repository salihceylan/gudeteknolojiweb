import { launch, ready, sleep, URL0, shot } from './util.mjs';
const theme = process.argv[2] || 'dark';
const s = await launch({ colorScheme: theme });
const { page, log } = s;
await page.goto(URL0 + '?theme=' + theme, { waitUntil: 'load' });
await ready(page); await sleep(2500);
await page.mouse.move(700, 450);
for (let i = 0; i < 10; i++) { await page.keyboard.press('Tab'); await sleep(150); }
await page.keyboard.press('Enter'); await sleep(2200);
const files = [await shot(page, `kb5_${theme}_open`)];
for (let i = 1; i <= 7; i++) { await page.keyboard.press('Tab'); await sleep(900); files.push(await shot(page, `kb5_${theme}_t${i}`)); }
await page.keyboard.press('Escape'); await sleep(2000);
files.push(await shot(page, `kb5_${theme}_esc`));
await page.keyboard.press('Tab'); await sleep(900);
files.push(await shot(page, `kb5_${theme}_afteresc_tab`));
console.log(files.length, log.errors);
await s.close();
