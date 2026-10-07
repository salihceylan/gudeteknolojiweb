import { openE, shotE, arg, sleep } from './lib2.mjs';
const s = await openE({ browser: 'edge', size: 'd1440', theme: 'dark', reduce: true });
await sleep(2000);
const files = [];
for (let i = 1; i <= 15; i++) { await s.page.keyboard.press('Tab'); await sleep(350); files.push(await shotE(s, `tab_${String(i).padStart(2, '0')}`)); }
console.log(files.join(' '));
await s.close();
