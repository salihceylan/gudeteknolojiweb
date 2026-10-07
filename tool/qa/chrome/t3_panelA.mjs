import { open, shot, sleep, report, tap } from './common.mjs';
const th = process.argv[2] || 'dark';
const s = await open({ theme: th });
await sleep(1500);
const P = s.page;
const log = (...a) => console.log(...a);
const MENU = [1388, 32];
// 1 aç
await tap(s, ...MENU); await sleep(300); log('opening mid', await shot(s, 't3A_open_mid'));
await sleep(1500); log('open', await shot(s, 't3A_open'));
// 2 kapat X
await tap(s, ...MENU); await sleep(300); log('closing mid', await shot(s, 't3A_close_mid'));
await sleep(1500); log('closedX', await shot(s, 't3A_closedX'));
// 3 scrim
await tap(s, ...MENU); await sleep(1800);
await tap(s, 300, 450); await sleep(1800); log('closed scrim', await shot(s, 't3A_closed_scrim'));
// 4 Esc
await tap(s, ...MENU); await sleep(1800);
await P.keyboard.press('Escape'); await sleep(1800); log('closed esc', await shot(s, 't3A_closed_esc'));
// 5 arka sayfa kaydırma: panel açıkken tekerlek
await tap(s, ...MENU); await sleep(1800);
await P.mouse.move(300, 450);
for (let i = 0; i < 8; i++) { await P.mouse.wheel(0, 100); await sleep(30); }
await sleep(2000); log('wheel over scrim', await shot(s, 't3A_wheel_scrim'));
await P.mouse.move(1240, 600);
for (let i = 0; i < 8; i++) { await P.mouse.wheel(0, 100); await sleep(30); }
await sleep(2000); log('wheel over panel', await shot(s, 't3A_wheel_panel'));
await tap(s, ...MENU); await sleep(1800); log('after close', await shot(s, 't3A_after_close'));
log(report(s));
await s.close();
