import { open, shot, sleep, report } from './common.mjs';
const s = await open({ theme: 'dark' });
await sleep(2000);
const P = s.page;
for (let i = 0; i < 11; i++) { await P.keyboard.press('Tab'); await sleep(250); }
await sleep(500); console.log('tab11', await shot(s, 't5k2_tab11'));
await P.keyboard.press('PageDown'); await sleep(3000); console.log('pagedown', await shot(s, 't5k2_pagedown'));
await P.keyboard.press('ArrowDown'); await P.keyboard.press('ArrowDown'); await P.keyboard.press('ArrowDown'); await sleep(3000); console.log('arrows', await shot(s, 't5k2_arrows'));
console.log(report(s)); await s.close();
