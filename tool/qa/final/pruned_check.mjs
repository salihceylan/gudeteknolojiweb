import { open, shot, report, sleep } from '../harness.mjs';
for (const browser of ['chrome', 'edge']) {
  const s = await open({ browser, device: 'desktop', url: 'http://localhost:8101/', theme: 'dark' });
  await sleep(1500);
  console.log(browser, 'açıldı;', await shot(s, `pruned_${browser}`));
  console.log(report(s));
  await s.close();
}
