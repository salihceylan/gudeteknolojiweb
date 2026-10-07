import { open, shot, tap, sleep } from '../harness.mjs';
const s = await open({ browser: 'chrome', device: 'desktop', url: 'http://localhost:8100/', theme: 'dark' });
await tap(s, 1386, 32); await sleep(2500);
for (let i = 1; i <= 4; i++) { await s.page.keyboard.press('Tab'); await sleep(700); console.log('Tab', i, await shot(s, `kb_tab${i}`)); }
await s.page.keyboard.press('Enter'); await sleep(4500);
console.log('Enter sonrası', await shot(s, 'kb_enter'));
console.log('hata:', s.errors.length);
await s.close();
