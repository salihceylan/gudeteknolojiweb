import { openM, shot, scrollBy, sleep, report } from './lib.mjs';
const dev = process.argv[2] || 'iphone', theme = process.argv[3] || 'dark', n = +(process.argv[4] || 14);
const s = await openM(dev, theme);
const vh = s.page.viewportSize().height;
await sleep(1500);
for (let i = 0; i < n; i++) {
  console.log(await shot(s, `m2_walk_${String(i).padStart(2, '0')}`));
  await scrollBy(s, vh * 0.8); await sleep(1500);
}
console.log(report(s));
await s.close();
