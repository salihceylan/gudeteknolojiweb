import { connect, tapCss, sleep, adb, measureFrames } from './lib.mjs';
const s = await connect();
const foc = () => adb('shell', 'dumpsys', 'window').split('\n').filter((l) => l.includes('mCurrentFocus')).join('').trim().slice(0, 100);
const where = process.argv[2];
const items = { iletisim: [103, 399], urunler: [104, 215], hizmet: [117, 261], kamera: [164, 168] };
const [x, y] = items[where];
tapCss(375, 30); await sleep(3000); tapCss(x, y); await sleep(4000);
for (let i = 0; i < 6; i++) { await sleep(10000); console.log(where, (i + 1) * 10 + 's', foc()); }
process.exit(0);
