import { launch, ready, sleep, URL0, shot } from './util.mjs';
const [w, h, start, step, n] = process.argv.slice(2);
const W = +w, H = +h;
const s = await launch({ viewport: { width: W, height: H } });
const { page, log } = s;
await page.goto(URL0 + `?scroll=${start}`, { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(3500);
await page.mouse.move(W / 2, H / 2);
const files = [];
for (let i = 0; i < +n; i++) {
  files.push(await shot(page, `snap_${W}x${H}_${i}`));
  const per = +step / 4;
  for (let k = 0; k < 4; k++) { await page.mouse.wheel(0, per); await sleep(16); }
  await sleep(1800);
}
console.log(files.length, log.errors);
await s.close();
