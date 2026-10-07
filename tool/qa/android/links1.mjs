import { connect, shot, tapCss, sleep, adb, screencap } from './lib.mjs';
const s = await connect();
const opened = [];
s.ctx.on('page', async (p) => { opened.push('new page'); try { await p.waitForLoadState('commit', { timeout: 5000 }); } catch {} opened.push('page url ' + p.url()); });
s.page.on('popup', (p) => opened.push('popup ' + p.url()));
console.log('pages before', s.ctx.pages().length);
tapCss(375, 30); await sleep(2200); tapCss(103, 399); await sleep(3500); // Iletisim
console.log(await shot(s, 'lk_00'));
tapCss(118, 306); await sleep(4000); // WhatsApp
console.log('after whatsapp', opened, 'pages', s.ctx.pages().map((p) => p.url()));
console.log(adb('shell', 'dumpsys', 'window').split('\n').filter((l) => l.includes('mCurrentFocus')).join(''));
screencap('lk_wa');
process.exit(0);
