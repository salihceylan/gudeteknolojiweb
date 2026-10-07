import { openE, shotE, arg, sleep, report, collectLabelBoxes, tap, waitForFlutter, URL0 } from './lib2.mjs';
const [w, h] = arg(0, '1366x640').split('x').map(Number);
const s = await openE({ browser: 'edge', size: 'd1440', theme: 'dark' });
await s.page.setViewportSize({ width: w, height: h });
await s.page.goto(URL0 + '?theme=dark', { waitUntil: 'load', timeout: 90000 }); await waitForFlutter(s.page, 90000); await sleep(1500);
s.size = 'd1440';
const boxes = await collectLabelBoxes(s);
const b = boxes.find((x) => x.role === 'button' && x.y < 70 && x.label === 'Ürünler');
await tap(s, b.x + b.width / 2, b.y + b.height / 2); await sleep(3000);
console.log('A at Ürünler', await shotE(s, `short_A`));
await s.page.mouse.move(w / 2, h / 2);
await s.page.mouse.wheel(0, 120); await sleep(3000);
console.log('B +120', await shotE(s, `short_B`));
await s.page.mouse.wheel(0, -120); await sleep(3000);
console.log('C -120', await shotE(s, `short_C`));
// iki çentik küçük adımlarla
for (let i = 0; i < 3; i++) { await s.page.mouse.wheel(0, 40); await sleep(1200); }
await sleep(2500);
console.log('D 3x40', await shotE(s, `short_D`));
console.log(report(s));
await s.close();
