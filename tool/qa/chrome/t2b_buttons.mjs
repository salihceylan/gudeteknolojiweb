import { open, shot, sleep, report, tap } from './common.mjs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th });
await sleep(2000);
const P = s.page;
await tap(s, 294, 591); await sleep(3200); console.log('explore', await shot(s, 't2b_explore'));
await tap(s, 72, 31); await sleep(2800);
await tap(s, 500, 591); await sleep(3200); console.log('contactbtn', await shot(s, 't2b_bize'));
await tap(s, 72, 31); await sleep(2800);
await tap(s, 827, 29); await sleep(3200);
await tap(s, 185, 545); await sleep(3200); console.log('teklif isteyin', await shot(s, 't2b_teklifisteyin'));
await tap(s, 72, 31); await sleep(2800);
console.log('top again', await shot(s, 't2b_top'));
// klavye: Tab
for (let i = 1; i <= 4; i++) { await P.keyboard.press('Tab'); await sleep(600); console.log('tab', i, await shot(s, `t2b_tab${i}`)); }
await P.keyboard.press('PageDown'); await sleep(2800); console.log('tab then PageDown', await shot(s, 't2b_tab_pagedown'));
console.log(report(s));
await s.close();
