import { chromium } from 'playwright-core';
const variants = {
  'varsayılan': [],
  'd3d11': ['--use-gl=angle', '--use-angle=d3d11'],
  'swiftshader': ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
};
for (const [name, args] of Object.entries(variants)) {
  const t0 = Date.now();
  const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args });
  const page = await (await b.newContext({ viewport: { width: 1440, height: 900 } })).newPage();
  page.on('console', (m) => { if (m.type() === 'error') console.log('  console.error', m.text().slice(0, 160)); });
  await page.goto('http://localhost:8099/', { waitUntil: 'load' });
  try { await page.waitForFunction(() => !document.getElementById('boot'), null, { timeout: 40000 }); } catch { console.log(name, '| AÇILMADI'); await b.close(); continue; }
  const load = ((Date.now() - t0) / 1000).toFixed(1);
  const gl = await page.evaluate(() => { const c = document.createElement('canvas'); const g = c.getContext('webgl2'); if (!g) return 'yok'; const e = g.getExtension('WEBGL_debug_renderer_info'); return e ? g.getParameter(e.UNMASKED_RENDERER_WEBGL) : 'webgl2'; });
  const fps = await page.evaluate(() => new Promise((res) => { let n = 0; const s = performance.now(); const f = (t) => { n++; if (t - s < 3000) requestAnimationFrame(f); else res(Math.round(n / ((t - s) / 1000))); }; requestAnimationFrame(f); }));
  console.log(name, '| açılış', load + 's', '| GL:', gl, '| rAF fps:', fps);
  await b.close();
}
