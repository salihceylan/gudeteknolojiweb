import { connect, goto, shot, tapCss, sleep, rep } from './lib.mjs';
const s = await connect();
await goto(s, 'http://localhost:8099/');
const links = [['kamera', 164, 168], ['urunler', 104, 215], ['hizmet', 117, 261], ['surec', 95, 307], ['ref', 127, 353], ['iletisim', 103, 399]];
for (const [n, x, y] of links) {
  tapCss(375, 30); await sleep(2200);
  if (n === 'kamera') console.log('menu-4s', await shot(s, 'mm_open'));
  tapCss(x, y); await sleep(3500);
  console.log(n, await shot(s, 'mm_' + n));
}
console.log(rep(s));
process.exit(0);
