import { launch, ready, sleep, URL0, shot } from './util.mjs';
const theme = process.argv[2] || 'dark';
const s = await launch({ colorScheme: theme });
const { page, log } = s;
await page.goto(URL0 + '?theme=' + theme, { waitUntil: 'load' });
await ready(page); await sleep(2500);
await page.mouse.move(700, 450);
for (let i = 1; i <= 10; i++) { await page.keyboard.press('Tab'); await sleep(250); }
const files = [];
for (let i = 11; i <= 16; i++) {
  await page.keyboard.press('Tab'); await sleep(1500);
  files.push(await shot(page, `kb2_${theme}_tab${i}`));
}
console.log(files.join(' '));
console.log(log.errors);
await s.close();
