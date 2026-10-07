import { open, shot, sleep, report, tap, startCast } from './common.mjs';
const s = await open({});  // koyu, kayıtsız
await sleep(1500);
const P = s.page;
const ls = () => P.evaluate(() => { try { return localStorage.getItem('gude-theme'); } catch (e) { return 'ERR'; } });
const bg = () => P.evaluate(() => document.documentElement.getAttribute('data-theme') + ' | ' + document.querySelector('meta[name=theme-color]')?.content);
console.log('initial', await ls(), await bg());
// 1) tek tık koyu->açık ara kareler
let cast = await startCast(s, 'toggle1');
await tap(s, 1340, 32);
await sleep(1800);
let fr = await cast.stop();
console.log('frames toggle1', fr.length, fr.map((f) => f.t).join(','));
console.log('after toggle', await ls(), await bg());
// 2) açık->koyu
cast = await startCast(s, 'toggle2');
await tap(s, 1340, 32);
await sleep(1800);
fr = await cast.stop();
console.log('frames toggle2', fr.length, fr.map((f) => f.t).join(','));
console.log('after toggle2', await ls(), await bg());
// 3) hızlı art arda 5 tıklama (koyu -> koyu->açık->... sonuç açık olmalı: 5 tek sayı)
for (let i = 0; i < 5; i++) { await P.mouse.move(1340, 32); await P.mouse.down(); await P.mouse.up(); await sleep(90); }
await sleep(2200);
console.log('after 5 rapid', await ls(), await bg(), await shot(s, 't4_rapid5'));
for (let i = 0; i < 4; i++) { await P.mouse.move(1340, 32); await P.mouse.down(); await P.mouse.up(); await sleep(40); }
await sleep(2200);
console.log('after 4 more rapid', await ls(), await bg(), await shot(s, 't4_rapid4'));
console.log(report(s));
await s.close();
