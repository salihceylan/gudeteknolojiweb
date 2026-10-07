import { chromium } from 'playwright-core';
import fs from 'node:fs';
// node montage.mjs out.png cols scale a.png b.png ...
const [out, cols, scale, ...files] = process.argv.slice(2);
const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
const page = await b.newPage();
await page.goto('about:blank');
const urls = files.map((f) => 'data:image/png;base64,' + fs.readFileSync(f).toString('base64'));
const png = await page.evaluate(async ([urls, cols, scale, names]) => {
  const imgs = await Promise.all(urls.map((u) => new Promise((r) => { const i = new Image(); i.onload = () => r(i); i.src = u; })));
  const w = Math.round(imgs[0].width * scale), h = Math.round(imgs[0].height * scale);
  const rows = Math.ceil(imgs.length / cols); const cv = document.createElement('canvas'); cv.width = w * cols + 4 * (cols - 1); cv.height = (h + 16) * rows; const g = cv.getContext('2d');
  g.fillStyle = '#444'; g.fillRect(0, 0, cv.width, cv.height); g.font = '12px sans-serif';
  imgs.forEach((im, i) => { const x = (i % cols) * (w + 4), y = ((i / cols) | 0) * (h + 16); g.drawImage(im, x, y + 16, w, h); g.fillStyle = '#fff'; g.fillText(names[i], x + 2, y + 12); });
  return cv.toDataURL('image/png');
}, [urls, +cols, +scale, files.map((f) => f.split(/[\/]/).slice(-2).join('/'))]);
fs.writeFileSync(out, Buffer.from(png.split(',')[1], 'base64'));
await b.close();
console.log(out);
