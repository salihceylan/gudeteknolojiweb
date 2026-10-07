import { open, shot, clickLabel, report, sleep } from './harness.mjs';
const s = await open({ browser: 'chrome', device: 'desktop', url: 'http://localhost:8099/', theme: 'dark' });
await clickLabel(s, 'Menüyü aç veya kapat'); await sleep(2500);
console.log(await shot(s, 'smoke3_menu'));
console.log(report(s));
await s.close();
