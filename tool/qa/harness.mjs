// Siteyi gerçek tarayıcılarda gezmek için ortak donanım. Siteye dahil değildir (yalnızca geliştirici aracı).
//
// Kullanım (örnek):
//   import { open, shot, scrollBy, tap, settle, report } from './harness.mjs';
//   const s = await open({ browser: 'chrome', device: 'desktop', url: 'http://localhost:8099/' });
//   await shot(s, 'ilk'); await s.close(); console.log(report(s));
//
// Tarayıcılar: 'chrome' | 'edge' (sistemdeki kurulu sürümler) | 'android' (adb ile bağlı emülatördeki Chrome, CDP üzerinden).
// Not: Flutter CanvasKit metni canvas'a çizer. Etkileşim (tıklama/kaydırma/sürükleme) için `semantics` KAPALI kalmalı:
// erişilebilirlik ağacı açıkken fare/dokunma tıklamaları sayfada karşılık bulmuyor (semantics açık oturumlarda yalnızca
// DOM okunur). Öğelerin konumunu öğrenmek için `collectLabelBoxes(s)` kullanın (ağacı açar, okur, sayfayı yeniler).
import { chromium, devices } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

export const OUT = path.resolve(process.env.QA_OUT || path.join(process.cwd(), '..', '..', 'qa_out'));
fs.mkdirSync(OUT, { recursive: true });

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const ADB = process.env.ADB || 'adb';

/** Cihaz profilleri: masaüstü ve mobil (dokunma, DPR, mobil UA). */
export const PROFILES = {
  desktop: { viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 },
  desktop1080: { viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 },
  laptop: { viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 },
  tablet: { ...devices['iPad (gen 7)'] },
  tabletLandscape: { ...devices['iPad (gen 7) landscape'] },
  iphone: { ...devices['iPhone 14'] },
  pixel: { ...devices['Pixel 7'] },
  smallPhone: { viewport: { width: 360, height: 640 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, userAgent: devices['Pixel 7'].userAgent },
  phoneLandscape: { viewport: { width: 844, height: 390 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true, userAgent: devices['iPhone 14'].userAgent },
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export { sleep };

/** Sayfayı açar; konsol hatalarını/uyarılarını, sayfa hatalarını ve başarısız istekleri toplar. */
export async function open({ browser = 'chrome', device = 'desktop', url, theme, query = '', semantics = false, slow = 0 } = {}) {
  const profile = PROFILES[device] || PROFILES.desktop;
  const errors = [];
  const warnings = [];
  const failedRequests = [];
  let b, ctx, page, closeFn;

  if (browser === 'android') {
    // adb ile Chrome DevTools soketini yönlendir ve bağlan.
    execFileSync(ADB, ['forward', 'tcp:9222', 'localabstract:chrome_devtools_remote']);
    b = await chromium.connectOverCDP('http://localhost:9222');
    ctx = b.contexts()[0] || (await b.newContext());
    page = ctx.pages()[0] || (await ctx.newPage());
    closeFn = async () => { try { await page.close(); } catch {} };
  } else {
    b = await chromium.launch({
      executablePath: browser === 'edge' ? EDGE : CHROME,
      headless: true,
      args: ['--enable-gpu-rasterization', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
      slowMo: slow,
    });
    ctx = await b.newContext({ ...profile, locale: 'tr-TR', colorScheme: theme === 'light' ? 'light' : 'dark', reducedMotion: 'no-preference' });
    page = await ctx.newPage();
    closeFn = async () => { await ctx.close(); await b.close(); };
  }

  page.on('console', (m) => {
    const t = m.type();
    const text = m.text();
    if (t === 'error') errors.push(`[console.error] ${text}`);
    else if (t === 'warning') warnings.push(`[console.warn] ${text}`);
  });
  page.on('pageerror', (e) => errors.push(`[pageerror] ${e.message}`));
  page.on('requestfailed', (r) => failedRequests.push(`${r.failure()?.errorText} ${r.url()}`));
  page.on('response', (r) => { if (r.status() >= 400) failedRequests.push(`HTTP ${r.status()} ${r.url()}`); });

  const s = { page, ctx, browser, device, profile, errors, warnings, failedRequests, theme, shots: [], close: closeFn };
  const full = url + (query ? (url.includes('?') ? '&' : '?') + query : '');
  await page.goto(full, { waitUntil: 'load' });
  await waitForFlutter(page);
  if (semantics) await enableSemantics(page);
  await settle(s, 800);
  return s;
}

/** Flutter'ın ilk karesini bekler ("flutter-first-frame" olayı ya da flt-glass-pane). */
export async function waitForFlutter(page, timeout = 45000) {
  await page.waitForSelector('flt-glass-pane, flutter-view', { timeout });
  await page.waitForFunction(() => !document.getElementById('boot'), null, { timeout });
}

/** Erişilebilirlik ağacını açar (Flutter web, görünmez bir "placeholder" düğmesi sunar). */
export async function enableSemantics(page) {
  try {
    await page.evaluate(() => {
      const el = document.querySelector('flt-semantics-placeholder');
      if (el) el.click();
    });
    await page.waitForSelector('flt-semantics', { timeout: 5000 });
  } catch {
    // Semantics açılamadıysa koordinatla etkileşim kalır.
  }
}

export async function settle(s, ms = 600) {
  await sleep(ms);
}

/** Ekran görüntüsü: <OUT>/<ortam>/<ad>.png ve s.shots listesine yol ekler. */
export async function shot(s, name, opts = {}) {
  const dir = path.join(OUT, `${s.browser}-${s.device}${s.theme ? '-' + s.theme : ''}`);
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `${name}.png`);
  await s.page.screenshot({ path: file, fullPage: false, ...opts });
  s.shots.push(file);
  return file;
}

/** Sayfa kaydırma konumu (Flutter kaydırma alanı, CanvasKit içinde olduğundan scroll olayıyla ilerletilir). */
export async function scrollBy(s, dy, { steps = 8 } = {}) {
  const { page, profile } = s;
  const vp = page.viewportSize() || { width: 1440, height: 900 };
  const x = vp.width / 2, y = vp.height / 2;
  if (profile.hasTouch) {
    // Dokunmatik: CDP ile gerçekçi kaydırma hareketi
    const cdp = await s.ctx.newCDPSession(page);
    await cdp.send('Input.synthesizeScrollGesture', { x, y, yDistance: -dy, speed: 1400, gestureSourceType: 'touch' });
    await cdp.detach();
  } else {
    await page.mouse.move(x, y);
    const per = dy / steps;
    for (let i = 0; i < steps; i++) { await page.mouse.wheel(0, per); await sleep(16); }
  }
  await sleep(700);
}

/** Koordinata dokun/tıkla (CSS piksel). */
export async function tap(s, x, y) {
  if (s.profile.hasTouch) await s.page.touchscreen.tap(x, y);
  else { await s.page.mouse.move(x, y); await sleep(120); await s.page.mouse.down(); await sleep(60); await s.page.mouse.up(); }
  await sleep(250);
}

/** Erişilebilirlik ağacındaki öğeyi etikete göre bul. Flutter web etiketi `aria-label` yerine çoğunlukla metin olarak koyar. */
export function byLabel(s, label) {
  return s.page.locator('flt-semantics').filter({ hasText: label }).first();
}

/** Etiketli öğenin merkezine gerçek işaretçi olayıyla (fare/dokunma) tıklar. Erişilebilirlik düğmesine `locator.click()`
 *  Flutter'da etkileşim üretmediğinden koordinat kullanılır. */
export async function clickLabel(s, label) {
  const box = await byLabel(s, label).boundingBox();
  if (!box) throw new Error('öğe bulunamadı: ' + label);
  await tap(s, box.x + box.width / 2, box.y + box.height / 2);
  await sleep(300);
}

/** Karelenme ölçümü: [ms] süre rAF aralıklarını toplar. Dönen: {fps, p95Ms, worstMs, frames}. */
export async function measureFrames(s, ms = 2000) {
  return s.page.evaluate((dur) => new Promise((resolve) => {
    const times = [];
    let last = performance.now();
    const start = last;
    function tick(t) {
      times.push(t - last); last = t;
      if (t - start < dur) requestAnimationFrame(tick);
      else {
        const sorted = [...times].sort((a, b) => a - b);
        const avg = times.reduce((a, b) => a + b, 0) / times.length;
        resolve({ frames: times.length, fps: Math.round(1000 / avg), p95Ms: Math.round(sorted[Math.floor(sorted.length * 0.95)] || 0), worstMs: Math.round(sorted[sorted.length - 1] || 0) });
      }
    }
    requestAnimationFrame(tick);
  }), ms);
}

/** Toplanan hata/uyarı özeti (metin). */
export function report(s) {
  const lines = [];
  lines.push(`ortam: ${s.browser}/${s.device}${s.theme ? '/' + s.theme : ''}`);
  lines.push(`konsol hataları: ${s.errors.length}`);
  s.errors.slice(0, 30).forEach((e) => lines.push('  ' + e.slice(0, 400)));
  lines.push(`başarısız istek/HTTP>=400: ${s.failedRequests.length}`);
  s.failedRequests.slice(0, 20).forEach((e) => lines.push('  ' + e.slice(0, 300)));
  lines.push(`uyarılar: ${s.warnings.length}`);
  s.warnings.slice(0, 10).forEach((e) => lines.push('  ' + e.slice(0, 300)));
  return lines.join('\n');
}


/** Erişilebilirlik ağacını geçici açıp etiketli öğelerin konum/boyutunu (CSS px) okur, sonra sayfayı yenileyip
 *  semantics'i kapatır (etkileşim için). Dönen: [{label, role, x, y, width, height}]. Kaydırma konumu sıfırlanır. */
export async function collectLabelBoxes(s) {
  await enableSemantics(s.page);
  await sleep(800);
  const boxes = await s.page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((n) => {
    const r = n.getBoundingClientRect();
    const text = (n.getAttribute('aria-label') || n.textContent || '').trim().split(String.fromCharCode(10))[0];
    return { label: text, role: n.getAttribute('role'), x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height) };
  }).filter((b) => b.label && b.width > 0 && b.height > 0));
  await s.page.reload({ waitUntil: 'load' });
  await waitForFlutter(s.page);
  await sleep(800);
  return boxes;
}
