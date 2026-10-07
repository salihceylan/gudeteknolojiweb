import { chromium } from 'playwright-core';
const t0 = Date.now(); const log = (...a) => console.log(((Date.now() - t0) / 1000).toFixed(1) + 's', ...a);
const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await (await b.newContext({ viewport: { width: 1440, height: 900 }, locale: 'tr-TR' })).newPage();
page.on('console', (m) => log('console', m.type(), m.text().slice(0, 300)));
page.on('pageerror', (e) => log('pageerror', e.message.slice(0, 300)));
page.on('requestfailed', (r) => log('REQFAIL', r.url(), r.failure()?.errorText));
page.on('response', (r) => log(r.status(), r.headers()['content-type'] || '', r.headers()['content-encoding'] || '', r.url().replace('http://gudeteknoloji.com', '')));
await page.goto('http://gudeteknoloji.com/', { waitUntil: 'load', timeout: 90000 });
log('load');
for (let i = 0; i < 10; i++) {
  const st = await page.evaluate(() => ({ boot: !!document.getElementById('boot'), glass: !!document.querySelector('flt-glass-pane'), view: !!document.querySelector('flutter-view'), text: document.body.innerText.slice(0, 120) }));
  log(JSON.stringify(st)); if (st.glass) break;
  await new Promise((r) => setTimeout(r, 6000));
}
await b.close();
