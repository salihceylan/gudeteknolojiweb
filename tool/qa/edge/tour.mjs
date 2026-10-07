import { openEnv, shot, report, scrollBy, sleep, measureFrames } from './lib.mjs';
const [browser = 'edge', device = 'desktop', theme = 'dark', tag = 'tour'] = process.argv.slice(2);
const s = await openEnv({ browser, device, theme });
await sleep(2500);
const vh = s.page.viewportSize().height;
const out = [];
out.push(await shot(s, `${tag}_00_top`));
await scrollBy(s, vh * 0.45); await sleep(1500);
out.push(await shot(s, `${tag}_01_iris_mid`));
await scrollBy(s, vh * 0.5); await sleep(2500);
out.push(await shot(s, `${tag}_02_camera`));
for (let i = 3; i <= 10; i++) {
  await scrollBy(s, vh * 0.98); await sleep(2200);
  out.push(await shot(s, `${tag}_${String(i).padStart(2, '0')}`));
}
console.log(out.join('\n'));
console.log(JSON.stringify(await measureFrames(s, 1500)));
console.log(await s.page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth })));
console.log(report(s));
await s.close();
