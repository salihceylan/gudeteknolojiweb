import { chromium } from 'playwright-core';
const t0 = Date.now(); const log = (...a) => console.log(((Date.now() - t0) / 1000).toFixed(1) + 's', ...a);
const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const ctx = await b.newContext({ viewport: { width: 1440, height: 900 }, locale: 'tr-TR' });
const page = await ctx.newPage();
page.on('console', (m) => log('console', m.type(), m.text().slice(0, 200)));
page.on('pageerror', (e) => log('pageerror', e.message.slice(0, 300)));
page.on('requestfailed', (r) => log('reqfail', r.url()));
log('goto');
await page.goto('http://localhost:8099/', { waitUntil: 'load', timeout: 60000 });
log('loaded');
for (let i = 0; i < 12; i++) {
  const st = await page.evaluate(() => ({ boot: !!document.getElementById('boot'), glass: !!document.querySelector('flt-glass-pane'), view: !!document.querySelector('flutter-view'), sem: !!document.querySelector('flt-semantics-placeholder') }));
  log(JSON.stringify(st));
  await new Promise((r) => setTimeout(r, 2000));
}
await page.screenshot({ path: 'dbg.png' });
log('shot');
await b.close();
