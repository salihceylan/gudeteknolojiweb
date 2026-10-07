import { connect, goto, shot, tapCss, swipeCss, cdpDrag, cdpRelease, sleep, adb } from './lib.mjs';
const s = await connect();
const c = await s.ctx.newCDPSession(s.page);
await c.send('Emulation.setEmulatedMedia', { media: '', features: [{ name: 'prefers-color-scheme', value: '' }] });
await goto(s, 'http://localhost:8099/?scroll=11.2&theme=dark');
console.log(await shot(s, 'tk_00'));
for (const [i, d] of [[1, 250], [2, 250]]) {
  await cdpDrag(s, 206, 700, 700 - d, { steps: 15, hold: true }); await sleep(900);
  console.log(i, await shot(s, 'tk_0' + i));
  await cdpRelease(s); await sleep(3000);
  console.log(i + 'r', await shot(s, 'tk_0' + i + 'r'));
}
process.exit(0);
