import { launch, ready, sleep, URL0, shot } from './util.mjs';
const mode = process.argv[2] || 'reduce';
const s = await launch({ reducedMotion: mode });
const { page, log } = s;
await page.goto(URL0 + '?scroll=1', { waitUntil: 'load' });
await ready(page); await sleep(3500);
const files = [await shot(page, `cam_${mode}_0start`)];
await page.mouse.move(950, 420); await page.mouse.down();
for (let i = 1; i <= 12; i++) { await page.mouse.move(950 - i * 30, 420 + i * 2); await sleep(30); }
files.push(await shot(page, `cam_${mode}_1held`));
await page.mouse.up();
await sleep(150);
files.push(await shot(page, `cam_${mode}_2rel`));
await sleep(5000);
files.push(await shot(page, `cam_${mode}_3after5s`));
console.log(log.errors);
await s.close();
