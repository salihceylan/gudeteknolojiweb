import { launch, sleep, URL0, shot, OUT } from './util.mjs';
import fs from 'node:fs';
const [profile = 'fast3g', theme = 'dark', cacheMode = 'cold'] = process.argv.slice(2);
const P = { fast3g: { down: 1.6e6 / 8, up: 750e3 / 8, lat: 562 }, slow4g: { down: 4e6 / 8, up: 3e6 / 8, lat: 150 }, none: null };
const s = await launch({ colorScheme: theme });
const { page, log } = s;
await s.ctx.addInitScript((t) => { try { localStorage.setItem('gude-theme', t); } catch {} }, theme);
const cdp = await s.ctx.newCDPSession(page);
await cdp.send('Network.enable');
if (cacheMode === 'cold') await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
const p = P[profile];
if (p) await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: p.lat, downloadThroughput: p.down, uploadThroughput: p.up });
let bytes = 0; const per = {};
const urls = {};
cdp.on('Network.requestWillBeSent', (e) => { urls[e.requestId] = e.request.url; });
cdp.on('Network.loadingFinished', (e) => { bytes += e.encodedDataLength; const u = urls[e.requestId] || '?'; per[u] = e.encodedDataLength; });
await page.addInitScript(() => {
  window.__t = {};
  window.addEventListener('flutter-first-frame', () => { window.__t.firstFrame = performance.now(); });
  new PerformanceObserver((l) => { for (const e of l.getEntries()) window.__t[e.name] = e.startTime; }).observe({ type: 'paint', buffered: true });
});
const t0 = Date.now();
const nav = page.goto(URL0, { waitUntil: 'commit', timeout: 120000 });
await nav;
const shots = [];
let ff = null;
for (let i = 0; i < 60; i++) {
  await sleep(1500);
  const t = await page.evaluate(() => window.__t).catch(() => null);
  const hasBoot = await page.evaluate(() => !!document.getElementById('boot')).catch(() => null);
  const el = ((Date.now() - t0) / 1000).toFixed(1);
  if (i === 1 || i === 4 || i === 9) { shots.push(await shot(page, `net_${profile}_${theme}_${cacheMode}_${el}s`)); }
  if (t && t.firstFrame && !ff) { ff = t; console.log('firstFrame at perf', Math.round(t.firstFrame), 'wall', el, 's', JSON.stringify(t)); break; }
}
await sleep(1500);
shots.push(await shot(page, `net_${profile}_${theme}_${cacheMode}_final`));
const mb = (bytes / 1e6).toFixed(2);
console.log(profile, theme, cacheMode, 'total transferred MB', mb);
for (const [u, b] of Object.entries(per).sort((a, b) => b[1] - a[1]).slice(0, 12)) console.log('  ', (b / 1024).toFixed(0).padStart(6), 'KB', u.slice(0, 120));
console.log('errors', log.errors, 'failed', log.failed);
console.log(shots.join('\n'));
await s.close();
