import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page, log } = s;
await page.goto(URL0, { waitUntil: 'load' });
await ready(page); await sleep(2500);
await page.mouse.move(700, 450);
for (let i = 0; i < 11; i++) { await page.keyboard.press('Tab'); await sleep(200); }
const files = [];
for (const k of ['PageDown', 'ArrowDown', 'PageDown', 'End', 'Home']) {
  await page.keyboard.press(k); await sleep(2200);
  files.push(await shot(page, `kb4_${k}_${files.length}`));
}
console.log(files.join(' '));
await s.close();
