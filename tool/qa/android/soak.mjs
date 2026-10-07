import { connect, swipeCss, sleep, adb, measureFrames, shot } from './lib.mjs';
const s = await connect();
const heap = () => s.page.evaluate(() => Math.round(performance.memory.usedJSHeapSize / 1e6)).catch(() => -1);
const rss = () => { const o = adb('shell', 'dumpsys', 'meminfo', 'com.android.chrome'); const m = o.match(/TOTAL PSS:\s+(\d+)/) || o.match(/TOTAL\s+(\d+)/); return m ? Math.round(+m[1] / 1024) : '?'; };
console.log('start heapMB', await heap(), 'chromePSS_MB', rss());
const t0 = Date.now(); let n = 0; let dir = 1;
while (Date.now() - t0 < 140000) {
  for (let i = 0; i < 6; i++) { if (dir > 0) swipeCss(206, 650, 206, 150, 400); else swipeCss(206, 150, 206, 650, 400); await sleep(1400); n++; }
  dir = -dir;
  console.log(Math.round((Date.now() - t0) / 1000) + 's swipes', n, 'heapMB', await heap(), 'PSS_MB', rss());
}
console.log('fps end', await measureFrames(s, 2000));
console.log('errors', s.errors.length, s.errors.slice(0, 5));
process.exit(0);
