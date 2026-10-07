import { connect, goto, shot, tapCss, sleep, rep, adb } from './lib.mjs';
const s = await connect();
await goto(s, 'http://localhost:8099/');
const ls = () => s.page.evaluate(() => [localStorage.getItem('gude-theme'), matchMedia('(prefers-color-scheme: dark)').matches]);
console.log('init', await ls());
tapCss(327, 30); await sleep(2500);
console.log('after sun tap', await ls(), await shot(s, 't_01_light'));
tapCss(327, 30); await sleep(2500);
console.log('after 2nd tap', await ls(), await shot(s, 't_02_dark'));
// Menü -> Sistem
tapCss(375, 30); await sleep(2200);
tapCss(232, 728); await sleep(2000);
console.log('sistem (night no)', await ls(), await shot(s, 't_03_sys_day'));
adb('shell', 'cmd', 'uimode', 'night', 'yes'); await sleep(4000);
console.log('sistem (night yes)', await ls(), await shot(s, 't_04_sys_night'));
adb('shell', 'cmd', 'uimode', 'night', 'no'); await sleep(4000);
console.log('sistem (night no again)', await ls(), await shot(s, 't_05_sys_day2'));
console.log(rep(s));
process.exit(0);
