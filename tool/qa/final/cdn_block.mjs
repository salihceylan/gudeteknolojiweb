import { chromium } from 'playwright-core';
const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const ctx = await b.newContext({ viewport: { width: 1440, height: 900 }, locale: 'tr-TR' });
const page = await ctx.newPage();
const blocked = [];
await page.route(/gstatic\.com|googleapis\.com|googleusercontent\.com/, (r) => { blocked.push(r.request().url()); r.abort(); });
const errs = []; page.on('pageerror', (e) => errs.push(e.message)); page.on('console', (m) => { if (m.type() === 'error') errs.push(m.text().slice(0, 160)); });
await page.goto('http://localhost:8100/', { waitUntil: 'load' });
let ok = true;
try { await page.waitForFunction(() => !document.getElementById('boot'), null, { timeout: 60000 }); } catch { ok = false; }
await new Promise((r) => setTimeout(r, 2000));
await page.screenshot({ path: '../../qa_out/cdn_blocked.png' });
console.log('Google sunucuları engelliyken açıldı mı:', ok);
console.log('engellenen istekler:', JSON.stringify(blocked));
console.log('hatalar:', JSON.stringify(errs.slice(0, 5)));
await b.close();
