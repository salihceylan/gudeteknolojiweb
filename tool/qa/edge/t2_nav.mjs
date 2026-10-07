import { openE, shotE, arg, sleep, report, collectLabelBoxes, tap } from './lib2.mjs';
import { readNodes, find } from './probe.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const s0 = await openE({ browser, size, theme });
await sleep(2000);
const boxes = await collectLabelBoxes(s0);
const vp = s0.page.viewportSize();
const top = boxes.filter((b) => b.role === 'button' && b.y < 70).sort((a, b) => a.x - b.x);
console.log('topbar', top.map((b) => `${b.label}@${b.x},${b.y} ${b.width}x${b.height}`).join(' | '));
const names = ['Kamera', 'Ürünler', 'Hizmetler', 'Süreç', 'Referanslar', 'İletişim'];
const marks = { Kamera: 'KAMERA SİSTEMLERİ', 'Ürünler': 'İLK ÜRÜNÜMÜZ', Hizmetler: 'HİZMETLERİMİZ', 'Süreç': 'ÇALIŞMA ŞEKLİMİZ', Referanslar: 'REFERANSLAR', 'İletişim': 'İLETİŞİM' };
// Mutlak (kaydırmasız) işaret konumları
let n0 = await readNodes(s0);
const abs = {};
for (const k of names) { const m = find(n0, marks[k]); abs[k] = m ? m.y : null; }
console.log('abs marks', JSON.stringify(abs), 'viewport', JSON.stringify(vp));
await s0.close();
for (const nm of names) {
  const s = await openE({ browser, size, theme });
  await sleep(1500);
  const b = (await collectLabelBoxes(s)).find((x) => x.role === 'button' && x.y < 70 && x.label === nm);
  if (!b) { console.log('NO BUTTON', nm); await s.close(); continue; }
  await tap(s, b.x + b.width / 2, b.y + b.height / 2);
  await sleep(2800);
  const f = await shotE(s, `nav_${nm}`);
  const nodes = await readNodes(s);
  const m = find(nodes, marks[nm]);
  console.log(nm, 'shot', f, 'label y now', m ? m.y : null, 'abs', abs[nm], '=> scrollY ≈', m && abs[nm] != null ? abs[nm] - m.y : '?');
  if (s.errors.length) console.log(report(s));
  await s.close();
}
