import { connect, shot, tapCss, sleep, adb } from './lib.mjs';
const s = await connect();
const foc = () => adb('shell', 'dumpsys', 'window').split('\n').filter((l) => l.includes('mCurrentFocus')).join('').trim().slice(0, 110);
console.log('history length', await s.page.evaluate(() => history.length));
tapCss(375, 30); await sleep(2500);
console.log('menu open', await shot(s, 'bk_0'));
adb('shell', 'input', 'keyevent', '4'); await sleep(3000);
console.log('after back focus:', foc());
try { console.log('page url', s.page.url()); await shot(s, 'bk_1'); } catch (e) { console.log('page gone', e.message.slice(0, 80)); }
adb('shell', 'screencap', '-p', '/sdcard/bk.png');
process.exit(0);
