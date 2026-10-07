import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page, log, ctx } = s;
const cdp = await ctx.newCDPSession(page);
await cdp.send('Network.enable');
let cur = null; const stat = () => ({ n: 0, cache: 0, bytes: 0, list: [] });
let st = stat();
const urls = {};
cdp.on('Network.requestWillBeSent', (e) => { urls[e.requestId] = e.request.url; });
cdp.on('Network.responseReceived', (e) => { const fc = e.response.fromDiskCache || e.response.fromPrefetchCache; st.n++; if (fc) st.cache++; st.list.push((fc ? 'CACHE ' : 'NET   ') + e.response.status + ' ' + e.response.url.replace(URL0, '/').slice(0, 110) + ' cc=' + (e.response.headers['cache-control'] || e.response.headers['Cache-Control'] || '-')); });
cdp.on('Network.loadingFinished', (e) => { st.bytes += e.encodedDataLength; });
async function load(label, fn) {
  st = stat(); const t0 = Date.now();
  try { await fn(); await ready(page, 30000); } catch (e) { console.log(label, 'FAILED:', e.message.split('\n')[0]); }
  await sleep(2500);
  console.log(`== ${label}: ${((Date.now() - t0) / 1000).toFixed(1)}s reqs=${st.n} fromCache=${st.cache} netBytes=${(st.bytes / 1024).toFixed(0)}KB`);
  st.list.forEach((l) => console.log('   ', l));
}
await load('1st load', () => page.goto(URL0, { waitUntil: 'load', timeout: 60000 }));
console.log('SW regs:', await page.evaluate(async () => (await navigator.serviceWorker.getRegistrations()).length), 'controller:', await page.evaluate(() => !!navigator.serviceWorker.controller));
await load('2nd load (reload)', () => page.reload({ waitUntil: 'load', timeout: 60000 }));
await load('3rd load (goto)', () => page.goto(URL0, { waitUntil: 'load', timeout: 60000 }));
await ctx.setOffline(true);
await load('offline goto', () => page.goto(URL0, { waitUntil: 'load', timeout: 20000 }));
const f = await shot(page, 'offline_goto'); console.log(f);
await load('offline reload', () => page.reload({ waitUntil: 'load', timeout: 20000 }));
console.log(await page.evaluate(() => document.body.innerText.slice(0, 200)).catch(e => 'eval fail'));
console.log(log.errors.slice(0, 8));
await s.close();
