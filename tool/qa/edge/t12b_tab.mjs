import { openE, shotE, arg, sleep } from './lib2.mjs';
const s = await openE({ browser: 'edge', size: 'd1440', theme: 'dark', reduce: true, scroll: 0.95 });
await sleep(2500);
for (let i = 1; i <= 14; i++) { await s.page.keyboard.press('Tab'); await sleep(400); await shotE(s, `tabc_${String(i).padStart(2, '0')}`); }
await s.close();
