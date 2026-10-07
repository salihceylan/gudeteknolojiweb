import { launch, ready, sleep, URL0, shot } from './util.mjs';
import { execFileSync } from 'node:child_process';
const [w, h, theme = 'dark', maxN = '16', stepF = '0.8', q = ''] = process.argv.slice(2);
const W = +w, H = +h;
const s = await launch({ viewport: { width: W, height: H }, colorScheme: theme });
const { page, log } = s;
const t0 = Date.now();
await page.goto(URL0 + `?theme=${theme}${q}`, { waitUntil: 'load' });
await ready(page); await sleep(3000);
console.log('ready ms', Date.now() - t0);
await page.mouse.move(W / 2, H / 2);
const files = []; let prev = null;
for (let i = 0; i < +maxN; i++) {
  const f = await shot(page, `vp_${W}x${H}_${theme}_${String(i).padStart(2, '0')}`);
  files.push(f);
  const buf = (await import('node:fs')).readFileSync(f);
  const sig = buf.length + ':' + buf.subarray(2000, 2064).toString('hex');
  if (prev === sig) { console.log('end reached at', i); break; }
  prev = sig;
  const per = (H * +stepF) / 8;
  for (let k = 0; k < 8; k++) { await page.mouse.wheel(0, per); await sleep(16); }
  await sleep(2300);
}
console.log(files.length, 'shots', log.errors, log.warnings);
await s.close();
