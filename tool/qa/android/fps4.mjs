import { connect, countFlutterFrames, tapCss, sleep } from './lib.mjs';
const s = await connect();
const items = [['iletisim', 103, 399], ['hizmet', 117, 261], ['ref', 127, 353], ['surec', 95, 307], ['hizmet', 117, 261]];
for (const [n, x, y] of items) {
  tapCss(375, 30); await sleep(2000); tapCss(x, y); await sleep(4500);
  console.log(n, 'rAF requests in 2s:', await countFlutterFrames(s, 2000));
}
process.exit(0);
