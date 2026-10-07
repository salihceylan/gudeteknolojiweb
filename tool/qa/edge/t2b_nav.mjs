import { openE, shotE, arg, sleep, report, collectLabelBoxes, tap } from './lib2.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const names = arg(3, 'Referanslar,İletişim').split(',');
const s = await openE({ browser, size, theme });
await sleep(1500);
const boxes = await collectLabelBoxes(s);
for (const nm of names) {
  const b = boxes.find((x) => x.role === 'button' && x.y < 70 && x.label === nm);
  if (!b) { console.log('NO BUTTON', nm); continue; }
  await tap(s, b.x + b.width / 2, b.y + b.height / 2);
  await sleep(3000);
  console.log(nm, await shotE(s, `nav_${nm}`));
  // sayfa başına dön (logo)
  const lg = boxes.find((x) => x.label.startsWith('Güde Teknoloji, sayfanın'));
  await tap(s, lg.x + lg.width / 2, lg.y + lg.height / 2);
  await sleep(3000);
  console.log('logo->top', await shotE(s, `nav_logo_after_${nm}`));
}
console.log(report(s));
await s.close();
