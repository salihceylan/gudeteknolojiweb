import { connect, shot, tapCss, swipeCss, sleep, adb } from './lib.mjs';
const s = await connect();
const c = await s.ctx.newCDPSession(s.page);
await c.send('Emulation.setEmulatedMedia', { media: '', features: [{ name: 'prefers-color-scheme', value: '' }] });
tapCss(68, 728); await sleep(2000);
tapCss(375, 30); await sleep(2500);
await shot(s, 'l_00');
for (let i = 1; i <= 12; i++) { swipeCss(206, 650, 206, 150, 700); await sleep(2300); console.log(i, await shot(s, 'l_' + String(i).padStart(2, '0'))); }
process.exit(0);
