import { openE, shotE, arg, sleep, report, collectLabelBoxes, tap } from './lib2.mjs';
import { readNodes } from './probe.mjs';
const browser = arg(0, 'edge'), size = arg(1, 'd1440'), theme = arg(2, 'dark');
const s = await openE({ browser, size, theme });
await sleep(1500);
const boxes = await collectLabelBoxes(s);
const menuBtn = boxes.find((b) => b.label.startsWith('Menüyü'));
const themeBtn = boxes.find((b) => b.label.includes('temaya geç'));
console.log('menuBtn', JSON.stringify(menuBtn), 'themeBtn', JSON.stringify(themeBtn));
const cx = menuBtn.x + menuBtn.width / 2, cy = menuBtn.y + menuBtn.height / 2;
const vp = s.page.viewportSize();
// 1) aç
await tap(s, cx, cy); await sleep(300);
await shotE(s, 'panel_t300');
await sleep(1500);
console.log(await shotE(s, 'panel_open'));
// 2) Esc ile kapat
await s.page.keyboard.press('Escape'); await sleep(1800);
console.log(await shotE(s, 'panel_after_esc'));
// 3) yeniden aç, scrim tıkla
await tap(s, cx, cy); await sleep(1800);
await tap(s, 200, vp.height / 2); await sleep(1800);
console.log(await shotE(s, 'panel_after_scrim'));
// 4) aç, sandviç düğmesiyle kapat (X)
await tap(s, cx, cy); await sleep(1800);
await tap(s, cx, cy); await sleep(1800);
console.log(await shotE(s, 'panel_after_toggle'));
// 5) klavye: Tab odak ve Enter ile açma
await s.page.keyboard.press('Tab'); await sleep(300);
for (let i = 0; i < 3; i++) { await s.page.keyboard.press('Tab'); await sleep(200); }
console.log(await shotE(s, 'tab_focus_4'));
console.log(report(s));
await s.close();
