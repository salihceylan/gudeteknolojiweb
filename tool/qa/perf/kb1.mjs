import { launch, ready, sleep, URL0, shot } from './util.mjs';
const theme = process.argv[2] || 'dark';
const s = await launch({ colorScheme: theme });
const { page, log } = s;
await page.goto(URL0 + '?theme=' + theme, { waitUntil: 'load' });
await ready(page); await sleep(2500);
await page.mouse.move(700, 450);
for (let i = 1; i <= 11; i++) {
  await page.keyboard.press('Tab'); await sleep(900);
  console.log(i, await shot(page, `kb_${theme}_tab${i}`, { clip: { x: 0, y: 0, width: 1440, height: 80 } }));
}
console.log(await page.evaluate(() => window.scrollY + ' ' + document.activeElement?.tagName));
console.log(log.errors);
await s.close();
