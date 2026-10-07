import { open, shot, sleep, report, tap, OUT } from './common.mjs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th });
await sleep(1500);
const nav = { Kamera: [755, 29], 'Ürünler': [827, 29], Hizmetler: [907, 29], 'Süreç': [981, 29], Referanslar: [1061, 29], 'İletişim': [1146, 29] };
const files = [];
for (const [k, [x, y]] of Object.entries(nav)) {
  await tap(s, 72, 31); await sleep(2500);
  await tap(s, x, y);
  await sleep(450);
  files.push(await shot(s, `t2_${k}_mid`));
  await sleep(2600);
  files.push(await shot(s, `t2_${k}_end`));
}
console.log(files.join('\n'));
console.log(report(s));
await s.close();
