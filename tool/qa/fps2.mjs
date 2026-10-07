import { chromium } from 'playwright-core';
const t0 = Date.now();
const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await (await b.newContext({ viewport: { width: 1440, height: 900 } })).newPage();
await page.goto('http://localhost:8099/', { waitUntil: 'load' });
await page.waitForFunction(() => !document.getElementById('boot'), null, { timeout: 60000 });
console.log('açılış', ((Date.now() - t0) / 1000).toFixed(1) + 's');
for (const label of ['hero (kamera sahnesi yok)']) {
  const fps = await page.evaluate(() => new Promise((res) => { let n = 0; const s = performance.now(); let worst = 0, last = s; const f = (t) => { n++; worst = Math.max(worst, t - last); last = t; if (t - s < 4000) requestAnimationFrame(f); else res({ fps: +(n / ((t - s) / 1000)).toFixed(1), worstMs: Math.round(worst) }); }; requestAnimationFrame(f); }));
  console.log(label, JSON.stringify(fps));
}
const t1 = Date.now(); await page.screenshot({ path: 'fps2.png' }); console.log('screenshot ms', Date.now() - t1);
await b.close();
