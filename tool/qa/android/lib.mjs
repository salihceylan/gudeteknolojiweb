// Android Chrome (emülatör) yardımcıları: CDP bağlantısı (yenilemeden) + adb gerçek dokunma.
process.env.QA_OUT ||= 'G:/site/gudeteknolojiweb/qa_out';
import { chromium } from 'playwright-core';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
export const OUT = process.env.QA_OUT + '/android';
fs.mkdirSync(OUT, { recursive: true });
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export const adb = (...a) => spawnSync('adb', a, { encoding: 'utf8', maxBuffer: 1 << 26 }).stdout.trim();
export async function connect() {
  execFileSync('adb', ['forward', 'tcp:9222', 'localabstract:chrome_devtools_remote']);
  const b = await chromium.connectOverCDP('http://127.0.0.1:9222');
  const ctx = b.contexts()[0];
  const page = ctx.pages()[0];
  const s = { b, ctx, page, errors: [], warnings: [], failed: [], logs: [] };
  page.on('console', (m) => { const t = m.type(); if (t === 'error') s.errors.push(m.text()); else if (t === 'warning') s.warnings.push(m.text()); else s.logs.push(m.text()); });
  page.on('pageerror', (e) => s.errors.push('[pageerror] ' + e.message));
  page.on('requestfailed', (r) => s.failed.push(r.failure()?.errorText + ' ' + r.url()));
  page.on('response', (r) => { if (r.status() >= 400) s.failed.push('HTTP ' + r.status() + ' ' + r.url()); });
  return s;
}
export async function goto(s, url) { await s.page.goto(url, { waitUntil: 'load' }); await s.page.waitForSelector('flt-glass-pane, flutter-view', { timeout: 60000 }); await s.page.waitForFunction(() => !document.getElementById('boot'), null, { timeout: 60000 }); await sleep(4000); }
export async function geom(s) {
  return s.page.evaluate(() => ({ iw: innerWidth, ih: innerHeight, dpr: devicePixelRatio, ow: outerWidth, oh: outerHeight, sx: screenX, sy: screenY, vvw: visualViewport.width, vvh: visualViewport.height, scale: visualViewport.scale, ot: visualViewport.offsetTop, pt: visualViewport.pageTop, sw: document.documentElement.scrollWidth }));
}
/** adb ekran görüntüsü (cihaz pikseli, Chrome arayüzü dahil). */
export function screencap(name) { const f = path.join(OUT, name + '.png'); const r = spawnSync('adb', ['exec-out', 'screencap', '-p'], { maxBuffer: 1 << 28 }); fs.writeFileSync(f, r.stdout); return f; }
export async function shot(s, name) { const f = path.join(OUT, name + '.png'); await s.page.screenshot({ path: f, scale: 'css', timeout: 90000 }); return f; }
// CSS px -> ekran px. contentTop: sayfa içeriğinin ekran üstünden uzaklığı (px); calibrate() ile bulunur.
export const state = { top: 282, dpr: 2.625 };
export const px = (x, y) => [Math.round(x * state.dpr), Math.round(y * state.dpr + state.top)];
export const tapCss = (x, y) => { const [a, b] = px(x, y); adb('shell', 'input', 'tap', String(a), String(b)); };
export const swipeCss = (x1, y1, x2, y2, ms = 300) => { const [a, b] = px(x1, y1), [c, d] = px(x2, y2); adb('shell', 'input', 'swipe', String(a), String(b), String(c), String(d), String(ms)); };
/** Sayfa içinde bir CSS koordinatındaki isabeti doğrulamak için: Flutter'da pointer olayını dinleyen kayıt. */
export async function probeTouches(s) { await s.page.evaluate(() => { window.__t = []; ['pointerdown', 'pointerup', 'touchstart'].forEach((e) => window.addEventListener(e, (ev) => window.__t.push([e, Math.round(ev.clientX ?? ev.touches?.[0]?.clientX), Math.round(ev.clientY ?? ev.touches?.[0]?.clientY)]), true)); }); }
export const touches = (s) => s.page.evaluate(() => window.__t);
export async function measureFrames(s, ms = 2000) {
  return s.page.evaluate((dur) => new Promise((res) => { const t = []; let l = performance.now(); const st = l; const f = (n) => { t.push(n - l); l = n; if (n - st < dur) requestAnimationFrame(f); else { const so = [...t].sort((a, b) => a - b); const avg = t.reduce((a, b) => a + b, 0) / t.length; res({ frames: t.length, fps: Math.round(1000 / avg), p95Ms: Math.round(so[Math.floor(so.length * .95)] || 0), worstMs: Math.round(so[so.length - 1] || 0) }); } }; requestAnimationFrame(f); }), ms);
}
export const rep = (s) => `errors ${s.errors.length}: ${s.errors.slice(0, 10).join(' | ')}\nwarnings ${s.warnings.length}: ${s.warnings.slice(0, 10).join(' | ')}\nfailed ${s.failed.length}: ${s.failed.slice(0, 10).join(' | ')}`;
/** CDP ile tutulabilen dokunma sürüklemesi. */
export async function cdpDrag(s, x, y0, y1, { steps = 12, hold = false, dx = 0, stepMs = 25 } = {}) {
  const c = s.cdp ||= await s.ctx.newCDPSession(s.page);
  await c.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y: y0 }] });
  for (let i = 1; i <= steps; i++) { await c.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x + dx * i / steps, y: y0 + (y1 - y0) * i / steps }] }); await sleep(stepMs); }
  if (!hold) await c.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}
export async function cdpRelease(s) { const c = s.cdp; await c.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); }
/** Flutter'ın kare isteklerini sayar (rAF sarmalayıcı): boşta sahnede ~0 olmalı. */
export async function countFlutterFrames(s, ms = 2000) {
  return s.page.evaluate((dur) => new Promise((res) => {
    const orig = window.requestAnimationFrame.bind(window);
    let n = 0; let mine = false;
    window.requestAnimationFrame = (cb) => { if (!mine) n++; return orig(cb); };
    setTimeout(() => { window.requestAnimationFrame = orig; res(n); }, dur);
  }), ms);
}
export async function cdpTap(s, x, y) {
  const c = s.cdp ||= await s.ctx.newCDPSession(s.page);
  await c.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
  await sleep(60);
  await c.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}
