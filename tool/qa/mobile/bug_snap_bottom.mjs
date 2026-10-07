// Sayfa sonuna in, alt bilgi görününce boş bir yere dokun: sayfa iletişim sahnesinin başına geri yaslanır (alt bilgi gizlenir).
import { openM, shot, sleep, dragStart, dragMove, dragEnd, tap } from './lib.mjs';
const s = await openM('smallPhone', 'dark');
const vp = s.page.viewportSize(); const x = vp.width / 2; await sleep(1500);
for (let i = 0; i < 26; i++) { const y0 = vp.height * 0.85, y1 = y0 - vp.height * 0.7; await dragStart(s, x, y0); for (let k = 1; k <= 10; k++) { await dragMove(s, x, y0 + (y1 - y0) * k / 10); await sleep(30); } await sleep(300); await dragEnd(s); await sleep(1300); }
console.log('A sayfa sonu', await shot(s, 'bug_snap_A'));
await tap(s, x, vp.height * 0.55); await sleep(1800);
console.log('B tek dokunus sonrasi', await shot(s, 'bug_snap_B'));
await dragStart(s, x, vp.height * 0.8); for (let k = 1; k <= 6; k++) { await dragMove(s, x, vp.height * 0.8 - k * 30); await sleep(30); } await sleep(300); await dragEnd(s); await sleep(1800);
console.log('C asagi surukleme sonrasi', await shot(s, 'bug_snap_C'));
await tap(s, x, vp.height * 0.55); await sleep(1800);
console.log('D tek dokunus sonrasi', await shot(s, 'bug_snap_D'));
await s.close();
