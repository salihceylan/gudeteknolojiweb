import { launch, ready, sleep, URL0 } from './util.mjs';
const s = await launch();
const { page, log } = s;
await page.goto(URL0, { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(2500);
const read = () => page.evaluate(() => ({ theme: document.querySelector('meta[name=theme-color]').content, cs: document.querySelector('meta[name=color-scheme]').content, dt: document.documentElement.getAttribute('data-theme'), lang: document.documentElement.lang, htmlBg: getComputedStyle(document.documentElement).backgroundColor, bodyBg: getComputedStyle(document.body).backgroundColor, ls: localStorage.getItem('gude-theme'), title: document.title, canvasBg: getComputedStyle(document.querySelector('flutter-view')).backgroundColor }));
console.log('initial', JSON.stringify(await read()));
await page.mouse.move(1340, 32); await sleep(100); await page.mouse.down(); await page.mouse.up(); await sleep(2000);
console.log('after toggle', JSON.stringify(await read()));
await page.mouse.move(1340, 32); await sleep(100); await page.mouse.down(); await page.mouse.up(); await sleep(2000);
console.log('toggle back', JSON.stringify(await read()));
// system mode: panel -> Sistem
await page.mouse.move(1388, 32); await sleep(100); await page.mouse.down(); await page.mouse.up(); await sleep(2000);
// ikonlar ve manifest
for (const u of ['favicon.png', 'manifest.json', 'icons/Icon-192.png', 'icons/Icon-512.png', 'icons/Icon-maskable-192.png', 'icons/Icon-maskable-512.png', 'version.json', 'robots.txt', 'sitemap.xml', 'favicon.ico', 'og-image.png', 'flutter_service_worker.js']) {
  const r = await page.request.get(URL0 + u); console.log(r.status(), u, r.headers()['content-type'], r.headers()['content-length']);
}
console.log('errors', log.errors, 'failed', log.failed);
await s.close();
