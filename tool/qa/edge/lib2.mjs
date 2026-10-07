import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import * as H from '../harness.mjs';
export { sleep, scrollBy, tap, measureFrames, report, collectLabelBoxes, enableSemantics, waitForFlutter, PROFILES, OUT } from '../harness.mjs';
const sleep = H.sleep;
H.PROFILES.d1024 = { viewport: { width: 1024, height: 768 }, deviceScaleFactor: 1 };
export const URL0 = 'http://localhost:8099/';
H.PROFILES.d1440t = { viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1, hasTouch: true };
H.PROFILES.d1024t = { viewport: { width: 1024, height: 768 }, deviceScaleFactor: 1, hasTouch: true };
export const DEVICE = { d1440: 'desktop', d1024: 'd1024', d1440t: 'd1440t', d1024t: 'd1024t' };
export const OUTDIR = 'G:/site/gudeteknolojiweb/qa_out';
const EXE = { edge: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', chrome: 'C:/Program Files/Google/Chrome/Application/chrome.exe' };

/** o: {browser,size,theme,scroll,menu,reduce,query,semantics}. Harness'ten farkı: uzun zaman aşımı + yeniden deneme (makine yoğun). */
export async function openE(o = {}) {
  const browser = o.browser || 'edge', size = o.size || 'd1440', theme = o.theme;
  const profile = H.PROFILES[DEVICE[size]];
  const q = [theme ? 'theme=' + theme : '', o.scroll != null ? 'scroll=' + o.scroll : '', o.menu ? 'menu=1' : '', o.query || ''].filter(Boolean).join('&');
  const url = URL0 + (q ? '?' + q : '');
  const errors = [], warnings = [], failedRequests = [], pages = [];
  const t0 = Date.now();
  const b = await chromium.launch({ executablePath: EXE[browser], headless: true, args: ['--enable-gpu-rasterization', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const ctx = await b.newContext({ ...profile, locale: 'tr-TR', colorScheme: theme === 'light' ? 'light' : 'dark', reducedMotion: o.reduce ? 'reduce' : 'no-preference', permissions: o.permissions });
  const page = await ctx.newPage();
  page.on('console', (m) => { const t = m.type(); const text = m.text(); if (t === 'error') errors.push(`[console.error] ${text}`); else if (t === 'warning') warnings.push(`[console.warn] ${text}`); });
  page.on('pageerror', (e) => errors.push(`[pageerror] ${e.message}`));
  page.on('requestfailed', (r) => failedRequests.push(`${r.failure()?.errorText} ${r.url()}`));
  page.on('response', (r) => { if (r.status() >= 400) failedRequests.push(`HTTP ${r.status()} ${r.url()}`); });
  ctx.on('page', (p) => { pages.push(p); });
  const s = { page, ctx, browser, device: DEVICE[size], profile, errors, warnings, failedRequests, theme, size, pages, shots: [], b };
  s.close = async () => { try { await ctx.close(); } catch {} try { await b.close(); } catch {} };
  if (o.pre) await o.pre(s);
  for (let i = 0; i < 3; i++) {
    try { await page.goto(url, { waitUntil: 'load', timeout: 90000 }); await H.waitForFlutter(page, 90000); break; }
    catch (e) { if (i === 2) { await s.close(); throw e; } await sleep(1000); }
  }
  s.loadMs = Date.now() - t0;
  await sleep(800);
  return s;
}
export async function shotE(s, name, opts = {}) {
  const dir = path.join(OUTDIR, `${s.browser}-${s.size}-${s.theme || 'dark'}`);
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, name + '.png');
  await s.page.screenshot({ path: file, ...opts });
  return file;
}
export const arg = (i, d) => process.argv[2 + i] ?? d;
