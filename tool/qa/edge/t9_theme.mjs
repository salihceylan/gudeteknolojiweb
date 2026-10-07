import { openE, shotE, arg, sleep, report, waitForFlutter, URL0 } from './lib2.mjs';
const browser = arg(0, 'edge');
const s = await openE({ browser, size: 'd1440', query: 'x=1' });
const st = () => s.page.evaluate(() => ({ ls: localStorage.getItem('gude-theme'), dt: document.documentElement.getAttribute('data-theme'), tc: document.querySelector('meta[name=theme-color]')?.content, cs: document.querySelector('meta[name=color-scheme]')?.content, bg: getComputedStyle(document.body).backgroundColor }));
const m = s.page.mouse; const tap = async (x, y) => { await m.move(x, y); await sleep(120); await m.down(); await sleep(60); await m.up(); };
await sleep(1500);
console.log('initial', JSON.stringify(await st()));
await tap(1340, 32); await sleep(120);
console.log('toggle +120ms', await shotE(s, 'th_mid'));
await sleep(1800);
console.log('after toggle', JSON.stringify(await st()), await shotE(s, 'th_light'));
await s.page.goto(URL0, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page); await sleep(2000);
console.log('reload no param', JSON.stringify(await st()), await shotE(s, 'th_reload_light'));
// panel aç, Koyu
await tap(1388, 32); await sleep(2000);
console.log('panel in light', await shotE(s, 'th_panel_light'));
await tap(1199, 770); await sleep(1800);
console.log('after Koyu', JSON.stringify(await st()), await shotE(s, 'th_panel_dark'));
await tap(1122, 770); await sleep(1800);
console.log('after Açık', JSON.stringify(await st()));
// Sistem + sistem koyu
await s.page.emulateMedia({ colorScheme: 'dark' }); await sleep(500);
await tap(1283, 770); await sleep(2000);
console.log('Sistem (os dark)', JSON.stringify(await st()), await shotE(s, 'th_sys_dark'));
await s.page.emulateMedia({ colorScheme: 'light' }); await sleep(2000);
console.log('Sistem (os light)', JSON.stringify(await st()), await shotE(s, 'th_sys_light'));
// reload persistence for system
await s.page.goto(URL0, { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page); await sleep(2000);
console.log('reload system', JSON.stringify(await st()));
console.log(report(s));
await s.close();
