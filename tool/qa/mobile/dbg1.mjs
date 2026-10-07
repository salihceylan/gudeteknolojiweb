import { openM, sleep, dragStart, dragEnd } from './lib.mjs';
const dev = process.argv[2];
const s = await openM(dev, 'dark');
await sleep(2000);
const n = async () => s.page.evaluate(() => document.querySelectorAll('flt-semantics').length + ' ph:' + !!document.querySelector('flt-semantics-placeholder'));
await dragStart(s, 180, 320); await sleep(80); await dragEnd(s); await sleep(1500); console.log('cdp touch', await n());
await s.page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await sleep(1500); console.log('click', await n());
await s.page.evaluate(() => { const p=document.querySelector('flt-semantics-placeholder'); if(!p) return; for (const t of ['pointerdown','pointerup','touchstart','touchend','mousedown','mouseup','click']) p.dispatchEvent(new Event(t,{bubbles:true})); }); await sleep(1500); console.log('events', await n());
await s.close();
