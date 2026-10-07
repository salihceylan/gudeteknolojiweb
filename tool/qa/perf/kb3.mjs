import { launch, ready, sleep, URL0, shot } from './util.mjs';
const mode = process.argv[2] || 'nofocus';
const s = await launch();
const { page, log } = s;
await page.goto(URL0, { waitUntil: 'load' });
await ready(page); await sleep(2500);
await page.mouse.move(700, 450);
if (mode === 'click') { await page.mouse.click(300, 700); await sleep(500); }
const steps = [['ArrowDown',5],['PageDown',1],['Space',1],['PageDown',2],['End',1],['Home',1]];
const files = [];
for (const [k, n] of steps) {
  for (let i = 0; i < n; i++) { await page.keyboard.press(k === 'Space' ? ' ' : k); await sleep(120); }
  await sleep(1800);
  files.push(await shot(page, `kb3_${mode}_${k}`));
}
console.log(files.join(' '));
console.log(log.errors);
await s.close();
