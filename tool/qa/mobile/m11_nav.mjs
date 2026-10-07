import { openM, shot, sleep, report, tap, collectLabelBoxes, waitForFlutter } from './lib.mjs';
const dev = process.argv[2] || 'iphone', theme = process.argv[3] || 'dark';
const s = await openM(dev, theme, 'menu=1');
await sleep(2500);
const boxes = await collectLabelBoxes(s); await sleep(2500);
const ids = ['Kamera Sistemleri', 'Ürünler', 'Hizmetler', 'Süreç', 'Referanslar', 'İletişim'];
const files = [];
for (const id of ids) {
  const b = boxes.find(x => x.label.startsWith(id) && x.role === 'button');
  if (!b) { console.log('yok', id); continue; }
  await tap(s, b.x + b.width / 2, b.y + b.height / 2);
  await sleep(2800);
  files.push(await shot(s, 'm11_nav_' + id.split(' ')[0]));
  await s.page.reload({ waitUntil: 'load' }); await waitForFlutter(s.page); await sleep(2500);
}
console.log(files.join(' '));
console.log(report(s));
await s.close();
