import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
const OUT = 'G:/site/gudeteknolojiweb/qa_out';
const cfgs = (process.argv[2] || 'd1440-dark,d1440-light,d1024-dark,d1024-light').split(',');
const prefix = process.argv[3] || 'tour_';
const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
const page = await b.newPage();
await page.goto('about:blank');
for (const cfg of cfgs) {
  const ed = path.join(OUT, 'edge-' + cfg), ch = path.join(OUT, 'chrome-' + cfg);
  if (!fs.existsSync(ed) || !fs.existsSync(ch)) { console.log('missing dir', cfg); continue; }
  const names = fs.readdirSync(ed).filter((f) => f.startsWith(prefix) && fs.existsSync(path.join(ch, f)));
  fs.mkdirSync(path.join(OUT, 'diff-' + cfg), { recursive: true });
  for (const n of names) {
    const a = 'data:image/png;base64,' + fs.readFileSync(path.join(ed, n)).toString('base64');
    const c = 'data:image/png;base64,' + fs.readFileSync(path.join(ch, n)).toString('base64');
    const r = await page.evaluate(async ([a, c]) => {
      const load = (u) => new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = u; });
      const [ia, ic] = await Promise.all([load(a), load(c)]);
      const w = ia.width, h = ia.height;
      if (ic.width !== w || ic.height !== h) return { err: `size ${w}x${h} vs ${ic.width}x${ic.height}` };
      const cv = document.createElement('canvas'); cv.width = w; cv.height = h; const g = cv.getContext('2d', { willReadFrequently: true });
      g.drawImage(ia, 0, 0); const da = g.getImageData(0, 0, w, h).data;
      g.drawImage(ic, 0, 0); const dc = g.getImageData(0, 0, w, h).data;
      const out = g.createImageData(w, h);
      let sum = 0, big = 0; const gx = 12, gy = 8; const cells = new Array(gx * gy).fill(0);
      for (let i = 0; i < da.length; i += 4) {
        const d = (Math.abs(da[i] - dc[i]) + Math.abs(da[i + 1] - dc[i + 1]) + Math.abs(da[i + 2] - dc[i + 2])) / 3;
        sum += d;
        const p = i / 4, x = p % w, y = (p / w) | 0;
        if (d > 24) { big++; cells[((y * gy / h) | 0) * gx + ((x * gx / w) | 0)]++; out.data[i] = 255; out.data[i + 1] = 0; out.data[i + 2] = 60; out.data[i + 3] = 255; }
        else { const v = (da[i] + da[i + 1] + da[i + 2]) / 3 * 0.35; out.data[i] = v; out.data[i + 1] = v; out.data[i + 2] = v; out.data[i + 3] = 255; }
      }
      g.putImageData(out, 0, 0);
      return { mean: +(sum / (w * h)).toFixed(3), bigPct: +(big * 100 / (w * h)).toFixed(3), cells, png: cv.toDataURL('image/png') };
    }, [a, c]);
    if (r.err) { console.log(cfg, n, r.err); continue; }
    fs.writeFileSync(path.join(OUT, 'diff-' + cfg, n), Buffer.from(r.png.split(',')[1], 'base64'));
    const hot = r.cells.map((v, i) => [v, i]).filter(([v]) => v > 400).map(([v, i]) => `(${i % 12},${(i / 12) | 0}):${v}`).join(' ');
    console.log(cfg.padEnd(11), n.padEnd(14), 'mean', String(r.mean).padEnd(7), 'big%', String(r.bigPct).padEnd(7), 'hot', hot);
  }
}
await b.close();
