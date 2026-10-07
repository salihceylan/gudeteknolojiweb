import { chromium } from 'playwright-core';
import fs from 'node:fs';
const dir = 'C:/Users/FINGON~1/AppData/Local/Temp/pw_returning_profile';
fs.rmSync(dir, { recursive: true, force: true });
const t0 = Date.now(); const log = (...a) => console.log(((Date.now() - t0) / 1000).toFixed(1) + 's', ...a);
const ctx = await chromium.launchPersistentContext(dir, { executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, viewport: { width: 1440, height: 900 }, locale: 'tr-TR', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = ctx.pages()[0] || await ctx.newPage();
page.on('pageerror', (e) => log('pageerror', e.message.slice(0, 200)));
page.on('console', (m) => { if (m.type() === 'error') log('console.error', m.text().slice(0, 200)); });
page.on('framenavigated', (f) => { if (f === page.mainFrame()) log('navigated', f.url()); });
async function waitReady(label) {
  const t = Date.now();
  for (let i = 0; i < 12; i++) {
    const st = await page.evaluate(() => ({ boot: !!document.getElementById('boot'), glass: !!document.querySelector('flt-glass-pane'), text: document.body.innerText.slice(0, 60) })).catch(() => ({ err: 1 }));
    if (st.glass && !st.boot) { log(label, 'HAZIR', ((Date.now() - t) / 1000).toFixed(1) + 's'); return true; }
    await new Promise((r) => setTimeout(r, 4000));
  }
  log(label, 'HAZIR DEĞİL', JSON.stringify(await page.evaluate(() => ({ boot: !!document.getElementById('boot'), text: document.body.innerText.slice(0, 100) })).catch(() => ({}))));
  return false;
}
await page.goto('http://gudeteknoloji.com/', { waitUntil: 'load' }); await waitReady('1. ziyaret');
await page.goto('http://gudeteknoloji.com/', { waitUntil: 'load' }); await waitReady('2. ziyaret (önbellekli)');
await page.reload({ waitUntil: 'load' }); await waitReady('3. ziyaret (yenile)');
await ctx.close();
