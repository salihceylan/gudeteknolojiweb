import { open, shot, sleep, report, tap, startCast } from './common.mjs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th });
await sleep(2000);
const P = s.page; await P.mouse.move(700, 450);
const nav = [['hero', null], ['Kamera', [755, 29]], ['Urunler', [827, 29]], ['screen', 'wheel'], ['Hizmetler', [907, 29]], ['Surec', [981, 29]], ['Referanslar', [1061, 29]], ['Iletisim', [1146, 29]]];
for (const [name, pos] of nav) {
  if (pos === 'wheel') { await P.mouse.wheel(0, 130); } else if (pos) { await tap(s, pos[0], pos[1]); await P.mouse.move(700, 300); }
  await sleep(4000);
  const cast = await startCast(s, 'act_' + name, { quality: 40 });
  await sleep(4000);
  const fr = await cast.stop();
  console.log(name, 'frames in 4s:', fr.length);
  await shot(s, 't7act_' + name);
}
console.log(report(s));
await s.close();
