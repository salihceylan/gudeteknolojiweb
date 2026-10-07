import { open, shot, sleep, report } from '../harness.mjs';
const SITE = 'http://127.0.0.1:8101/';
for (const [device, theme] of [['desktop', 'dark'], ['desktop', 'light'], ['iphone', 'dark'], ['smallPhone', 'light'], ['phoneLandscape', 'dark']]) {
  const s = await open({ browser: 'chrome', device, url: SITE, theme, query: `menu=1&theme=${theme}` });
  await sleep(3500);
  console.log(await shot(s, `panel_small2_${device}_${theme}`));
  console.log(device, theme, report(s).split('\n').filter(l => /hata|başarısız/.test(l)).join(' | '));
  await s.close();
}
