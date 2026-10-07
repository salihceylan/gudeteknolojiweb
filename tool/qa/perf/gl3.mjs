import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page, log, ctx } = s;
await page.goto(URL0 + '?scroll=1', { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(3500);
await shot(page, 'gl3_before');
const p2 = await ctx.newPage();
try { await p2.goto('chrome://gpucrash', { timeout: 8000 }); } catch (e) { console.log('gpucrash nav:', e.message.split('\n')[0]); }
await sleep(6000);
console.log('p1 alive?', await page.evaluate(() => document.title).catch((e) => 'eval fail ' + e.message.split('\n')[0]));
await shot(page, 'gl3_after_crash');
await page.mouse.move(1340, 32); await sleep(100); await page.mouse.down(); await page.mouse.up(); await sleep(3500);
await shot(page, 'gl3_after_crash_theme');
await sleep(3000);
await shot(page, 'gl3_after_crash_later');
console.log('errors', log.errors.slice(0, 8), 'warn', log.warnings.slice(0, 8));
await s.close();
