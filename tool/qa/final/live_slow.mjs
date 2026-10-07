// Yavaş bağlantıyı (≈ 2 Mbps) taklit eder: "yükleniyor" iletisi görünmeli, hata iletisi görünmemeli, sonunda site açılmalı.
import { chromium } from 'playwright-core';
const t0 = Date.now(); const log = (...a) => console.log(((Date.now() - t0) / 1000).toFixed(1) + 's', ...a);
const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const ctx = await b.newContext({ viewport: { width: 1440, height: 900 }, locale: 'tr-TR' });
const page = await ctx.newPage();
const cdp = await ctx.newCDPSession(page);
await cdp.send('Network.enable');
await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 80, downloadThroughput: 250 * 1024, uploadThroughput: 100 * 1024 }); // ~2 Mbps
const reqs = []; page.on('request', (r) => reqs.push(r.url().replace('http://gudeteknoloji.com/', '')));
await page.goto('http://gudeteknoloji.com/', { waitUntil: 'commit' });
let shownSlow = false, shownFail = false, ready = false;
for (let i = 0; i < 40 && !ready; i++) {
  await new Promise((r) => setTimeout(r, 3000));
  const st = await page.evaluate(() => ({ slow: !document.getElementById('boot-slow')?.hidden && !!document.getElementById('boot'), fail: !document.getElementById('boot-fail')?.hidden && !!document.getElementById('boot'), glass: !!document.querySelector('flt-glass-pane') && !document.getElementById('boot') })).catch(() => ({}));
  if (st.slow && !shownSlow) { shownSlow = true; log('"yükleniyor" iletisi görüldü'); await page.screenshot({ path: '../../qa_out/slow_msg.png' }); }
  if (st.fail && !shownFail) { shownFail = true; log('HATA iletisi görüldü'); }
  if (st.glass) { ready = true; log('site açıldı'); }
}
log('özet: slowMesaj=', shownSlow, ' hataMesajı=', shownFail, ' açıldı=', ready);
log('istenen ana dosyalar:', JSON.stringify(reqs.filter((u) => /main\.dart|flutter_bootstrap/.test(u))));
await b.close();
