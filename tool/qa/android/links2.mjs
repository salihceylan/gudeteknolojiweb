import { connect, tapCss, sleep, adb, screencap } from './lib.mjs';
const s = await connect();
const foc = () => adb('shell', 'dumpsys', 'window').split('\n').filter((l) => l.includes('mCurrentFocus')).join('').trim();
const key = (k) => adb('shell', 'input', 'keyevent', String(k));
console.log('start', foc());
const what = process.argv[2];
if (what === 'tel') { tapCss(118, 413); await sleep(3000); console.log('tel ->', foc()); screencap('lk_tel'); }
if (what === 'mail') { tapCss(118, 497); await sleep(3000); console.log('mail ->', foc()); screencap('lk_mail'); }
process.exit(0);
