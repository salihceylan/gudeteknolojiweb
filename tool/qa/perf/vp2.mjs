import { launch, ready, sleep, URL0, shot } from './util.mjs';
const [w, h, theme = 'dark', ...scr] = process.argv.slice(2);
const W = +w, H = +h;
const s = await launch({ viewport: { width: W, height: H }, colorScheme: theme });
const { page, log } = s;
const files = [];
for (const sc of scr) {
  await page.goto(URL0 + `?theme=${theme}&scroll=${sc}`, { waitUntil: 'load', timeout: 90000 });
  await ready(page); await sleep(3500);
  files.push(await shot(page, `vq_${W}x${H}_${theme}_${sc}`));
}
console.log(files.join(' ')); console.log(log.errors, log.warnings);
await s.close();
