import { connect, measureFrames, tapCss, sleep } from './lib.mjs';
const s = await connect();
const items = [['iletisim', 103, 399], ['hizmet', 117, 261], ['ref', 127, 353], ['surec', 95, 307], ['kamera', 164, 168], ['urunler', 104, 215]];
for (const [n, x, y] of items) {
  tapCss(375, 30); await sleep(2000); tapCss(x, y); await sleep(4500);
  const m = await measureFrames(s, 2500);
  const mem = await s.page.evaluate(() => Math.round(performance.memory.usedJSHeapSize / 1e6));
  console.log(n, JSON.stringify(m), 'heapMB', mem);
}
process.exit(0);
