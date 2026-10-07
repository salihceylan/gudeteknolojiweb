// Üretim derlemesi (localhost:8100) için hızlı yayın öncesi kontrol: Chrome masaüstü, CDN engelli açılış, iPhone, Edge.
import { open, shot, tap, sleep, report, measureFrames } from '../harness.mjs';
const SITE = 'http://localhost:8100/';
const log = (...a) => console.log(...a);

// ---- A) Chrome masaüstü
{
  const s = await open({ browser: 'chrome', device: 'desktop', url: SITE, theme: 'dark' });
  const reqs = []; s.page.on('request', (r) => reqs.push(r.url()));
  await s.page.reload({ waitUntil: 'load' }); await s.page.waitForFunction(() => !document.getElementById('boot'), null, { timeout: 60000 }); await sleep(1500);
  const lang = await s.page.evaluate(() => document.documentElement.lang);
  const external = [...new Set(reqs.filter((u) => !u.startsWith('http://localhost')).map((u) => new URL(u).host))];
  const cv = reqs.filter((u) => u.includes('canvaskit')).map((u) => u.replace(SITE, ''));
  log('A1 lang:', lang, '| dış alan adı istekleri:', JSON.stringify(external), '| canvaskit:', JSON.stringify(cv));
  log('A1', await shot(s, 'A1_open'));
  // tek tekerlek çentiği
  await s.page.mouse.move(720, 450); await s.page.mouse.wheel(0, 100); await sleep(3500);
  log('A2 tek çentik sonrası', await shot(s, 'A2_notch'));
  // klavye PageDown
  await s.page.keyboard.press('PageDown'); await sleep(3500);
  log('A3 PageDown sonrası', await shot(s, 'A3_pagedown'));
  await s.page.keyboard.press('Home'); await sleep(3500);
  log('A4 Home sonrası', await shot(s, 'A4_home'));
  // sandviç panel + klavye
  await tap(s, 1388, 32); await sleep(2500);
  log('A5 panel açık', await shot(s, 'A5_panel'));
  await s.page.keyboard.press('Tab'); await s.page.keyboard.press('Tab'); await sleep(500);
  await s.page.keyboard.press('Enter'); await sleep(4000);
  log('A6 panelde Tab+Tab+Enter sonrası', await shot(s, 'A6_panel_enter'));
  await tap(s, 1340, 32); await sleep(2500);
  log('A7 tema düğmesi', await shot(s, 'A7_theme'));
  log(report(s));
  await s.close();
}
// ---- B) Google sunucuları engelli açılış (CDN bağımlılığı kalmadı mı)
{
  const s = await open({ browser: 'chrome', device: 'desktop', url: 'about:blank', theme: 'dark', semantics: false }).catch(() => null);
  if (s) {
    await s.page.route(/gstatic\.com|googleapis\.com|googleusercontent/, (r) => r.abort());
    await s.page.goto(SITE, { waitUntil: 'load' });
    let ok = true;
    try { await s.page.waitForFunction(() => !document.getElementById('boot'), null, { timeout: 60000 }); } catch { ok = false; }
    await sleep(1500);
    log('B CDN engelli açıldı mı:', ok, '| dış istek hataları:', JSON.stringify(s.failedRequests.slice(0, 5)));
    log('B', await shot(s, 'B_cdn_blocked'));
    await s.close();
  }
}
// ---- C) iPhone emülasyonu
{
  const s = await open({ browser: 'chrome', device: 'iphone', url: SITE, theme: 'dark' });
  log('C1', await shot(s, 'C1_open'));
  const cdp = await s.ctx.newCDPSession(s.page);
  await cdp.send('Input.synthesizeScrollGesture', { x: 195, y: 500, yDistance: -300, speed: 1200, gestureSourceType: 'touch' }); await sleep(4000);
  log('C2 dokunmatik kaydırma sonrası', await shot(s, 'C2_swipe'));
  await tap(s, 366, 32); await sleep(2500);
  log('C3 panel', await shot(s, 'C3_panel'));
  log(report(s));
  await s.close();
}
// ---- D) Edge
{
  const s = await open({ browser: 'edge', device: 'desktop', url: SITE, theme: 'light' });
  log('D1', await shot(s, 'D1_open_light'));
  log(report(s));
  await s.close();
}
log('BİTTİ');
