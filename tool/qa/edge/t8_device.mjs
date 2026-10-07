import { openE, shotE, arg, sleep, report } from './lib2.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const s = await openE({ browser, size, theme, scroll: arg(3, '2.95') });
await sleep(2500);
const m = s.page.mouse;
// düğme konumu: tarama için ekran görüntüsünden (1440x900 @2.95: 375,421); 1024: 238,444
const pos = size.startsWith('d1440') ? [374, 550] : [238, 444];
console.log('0', await shotE(s, 'dev_0'));
await m.move(...pos); await sleep(600);
console.log('1 hover', await shotE(s, 'dev_1_hover'));
await m.down(); await sleep(500);
console.log('2 pressed 500ms', await shotE(s, 'dev_2_press'));
await sleep(1200);
console.log('3 pressed 1.7s', await shotE(s, 'dev_3_press_long'));
await m.up(); await sleep(600);
console.log('4 released', await shotE(s, 'dev_4_rel'));
await sleep(2500);
console.log('5 later', await shotE(s, 'dev_5_later'));
// kısa tıklama
await m.click(...pos); await sleep(700);
console.log('6 click', await shotE(s, 'dev_6_click'));
await sleep(2500);
console.log('7 click later', await shotE(s, 'dev_7_clicklater'));
console.log(report(s));
await s.close();
