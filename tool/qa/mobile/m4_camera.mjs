import { openM, shot, sleep, report, drag, dragStart, dragMove, dragEnd, waitForFlutter } from './lib.mjs';
const dev = process.argv[2] || 'iphone', theme = process.argv[3] || 'dark';
const s = await openM(dev, theme, 'scroll=0.95');
const vp = s.page.viewportSize(); const cx = vp.width / 2, cy = vp.height * 0.4;
const out = [];
await sleep(2500);
out.push(await shot(s, 'm4_cam_rest'));
// yatay: parmak basılı
await dragStart(s, cx - 100, cy);
for (let i = 1; i <= 10; i++) { await dragMove(s, cx - 100 + i * 20, cy + (i % 2)); await sleep(40); }
await sleep(500); out.push(await shot(s, 'm4_cam_h_held_right'));
for (let i = 1; i <= 10; i++) { await dragMove(s, cx + 100 + i * 8, cy); await sleep(40); }
await sleep(400); out.push(await shot(s, 'm4_cam_h_held_right2'));
await dragEnd(s); await sleep(500); out.push(await shot(s, 'm4_cam_h_rel500'));
await sleep(1500); out.push(await shot(s, 'm4_cam_h_rel2000'));
await sleep(4000); out.push(await shot(s, 'm4_cam_h_rel6000'));
console.log(out.join('\n'));
// dikey kamera üzerinde
await s.page.reload({ waitUntil: 'load' }); await waitForFlutter(s.page); await sleep(2500);
await dragStart(s, cx, cy + 80);
for (let i = 1; i <= 10; i++) { await dragMove(s, cx + (i % 2), cy + 80 - i * 25); await sleep(40); }
await sleep(600); out.push(await shot(s, 'm4_cam_v_held'));
await dragEnd(s); await sleep(2500); console.log(await shot(s, 'm4_cam_v_rel'));
// çapraz: yatay baskın
await s.page.reload({ waitUntil: 'load' }); await waitForFlutter(s.page); await sleep(2500);
await dragStart(s, cx - 80, cy + 40);
for (let i = 1; i <= 10; i++) { await dragMove(s, cx - 80 + i * 14, cy + 40 - i * 6); await sleep(40); }
await sleep(500); console.log('diag-h held', await shot(s, 'm4_cam_diagH_held'));
await dragEnd(s); await sleep(2500); console.log('diag-h rel', await shot(s, 'm4_cam_diagH_rel'));
// çapraz: dikey baskın
await s.page.reload({ waitUntil: 'load' }); await waitForFlutter(s.page); await sleep(2500);
await dragStart(s, cx - 20, cy + 100);
for (let i = 1; i <= 10; i++) { await dragMove(s, cx - 20 + i * 6, cy + 100 - i * 22); await sleep(40); }
await sleep(500); console.log('diag-v held', await shot(s, 'm4_cam_diagV_held'));
await dragEnd(s); await sleep(2500); console.log('diag-v rel', await shot(s, 'm4_cam_diagV_rel'));
console.log(report(s));
await s.close();
