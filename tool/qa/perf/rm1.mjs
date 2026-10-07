import { launch, ready, sleep, URL0, shot } from './util.mjs';
const mode = process.argv[2] || 'reduce';
const theme = process.argv[3] || 'dark';
const scrolls = (process.argv[4] || '0,1,1.9,2.6,3.4,4.2,4.9,5.7').split(',').map(Number);
const s = await launch({ reducedMotion: mode, colorScheme: theme });
const { page, log } = s;
const res = [];
for (const sc of scrolls) {
  await page.goto(URL0 + `?scroll=${sc}&theme=${theme}`, { waitUntil: 'load' });
  await ready(page); await sleep(3500);
  const a = await shot(page, `rm_${mode}_${theme}_${sc}_a`);
  await sleep(2500);
  const b = await shot(page, `rm_${mode}_${theme}_${sc}_b`);
  res.push([sc, a, b]);
}
console.log('done', log.errors, log.warnings);
await s.close();
