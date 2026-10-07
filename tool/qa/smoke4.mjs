import { open, collectLabelBoxes, tap, shot, sleep } from './harness.mjs';
const s = await open({ browser: 'chrome', device: 'desktop', url: 'http://localhost:8099/', theme: 'dark' });
const boxes = await collectLabelBoxes(s);
console.log(boxes.filter((b) => b.role === 'button').slice(0, 14).map((b) => `${b.label} @${b.x},${b.y} ${b.width}x${b.height}`).join('\n'));
const m = boxes.find((b) => b.label.startsWith('Menüyü aç'));
await tap(s, m.x + m.width / 2, m.y + m.height / 2); await sleep(2500);
console.log(await shot(s, 'smoke4_menu_open'));
await s.close();
