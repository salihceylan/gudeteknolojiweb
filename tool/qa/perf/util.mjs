import { chromium } from 'playwright-core';
import path from 'node:path';
import fs from 'node:fs';
export const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
export const ROOT = path.resolve(import.meta.dirname, '..', '..', '..');
export const OUT = path.join(ROOT, 'qa_out', 'perf');
fs.mkdirSync(OUT, { recursive: true });
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export const URL0 = 'http://localhost:8099/';
export async function launch(ctxOpts = {}, launchArgs = []) {
  const b = await chromium.launch({ executablePath: CHROME, headless: true,
    args: ['--enable-gpu-rasterization', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', ...launchArgs] });
  const ctx = await b.newContext({ viewport: { width: 1440, height: 900 }, locale: 'tr-TR', colorScheme: 'dark', ...ctxOpts });
  const page = await ctx.newPage();
  const log = { errors: [], warnings: [], failed: [], reqs: [], consoleAll: [] };
  page.on('console', (m) => { log.consoleAll.push(`[${m.type()}] ${m.text()}`); if (m.type() === 'error') log.errors.push(m.text()); if (m.type() === 'warning') log.warnings.push(m.text()); });
  page.on('pageerror', (e) => log.errors.push('pageerror ' + e.message));
  page.on('requestfailed', (r) => log.failed.push(`${r.failure()?.errorText} ${r.url()}`));
  page.on('response', (r) => { log.reqs.push({ url: r.url(), status: r.status(), len: Number(r.headers()['content-length'] || 0), fromSW: r.fromServiceWorker() }); });
  return { b, ctx, page, log, close: async () => { await Promise.race([(async () => { try { await ctx.close(); } catch {} try { await b.close(); } catch {} })(), sleep(6000)]); if (!globalThis.__keepAlive) setTimeout(() => process.exit(0), 200); } };
}
export async function ready(page, t = 60000) {
  await page.waitForSelector('flt-glass-pane, flutter-view', { timeout: t });
  await page.waitForFunction(() => !document.getElementById('boot'), null, { timeout: t });
}
export async function shot(page, name, opts = {}) {
  const f = path.join(OUT, name + '.png');
  await page.screenshot({ path: f, ...opts });
  return f;
}
