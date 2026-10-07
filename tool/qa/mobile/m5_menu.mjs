import { openM, shot, sleep, report, tap, collectLabelBoxes, waitForFlutter } from './lib.mjs';
const dev = process.argv[2] || 'iphone', theme = process.argv[3] || 'dark';
const s = await openM(dev, theme, 'menu=1');
await sleep(2500);
const evs = [];
s.ctx.on('page', (p) => evs.push('newpage ' + p.url()));
s.page.on('popup', (p) => evs.push('popup ' + p.url()));
s.page.on('framenavigated', (f) => evs.push('nav ' + f.url()));
console.log(await shot(s, 'm5_menu_open'));
const boxes = await collectLabelBoxes(s); // reload (menu=1 sorgusu korunur)
await sleep(2500);
console.log(boxes.filter(b => b.role === 'button' || b.role === 'group').map(b => `${b.role} | ${b.label.slice(0,36)} @${b.x},${b.y} ${b.width}x${b.height}`).join('\n'));
const find = (t) => boxes.find(b => b.label.startsWith(t) && b.role === 'button');
const c = (b) => [b.x + b.width / 2, b.y + b.height / 2];
// tema seçici
const acik = find('Açık tema'); 
if (acik) { await tap(s, ...c(acik)); await sleep(2000); console.log(await shot(s, 'm5_menu_light')); console.log('ls', await s.page.evaluate(() => localStorage.getItem('gude-theme'))); }
const sis = find('Sistem tema'); if (sis) { await tap(s, ...c(sis)); await sleep(2000); console.log('ls sys', await s.page.evaluate(() => localStorage.getItem('gude-theme'))); console.log(await shot(s, 'm5_menu_system')); }
const koyu = find('Koyu tema'); if (koyu) { await tap(s, ...c(koyu)); await sleep(1500); }
// iletişim bağlantıları
for (const t of ['(0) 543', 'bilgi@', 'WhatsApp', 'Teklif Pro']) {
  const b = find(t); if (!b) { console.log('yok', t); continue; }
  evs.length = 0; await tap(s, ...c(b)); await sleep(1500); console.log(t, '->', JSON.stringify(evs));
  for (const pg of s.ctx.pages().slice(1)) { try { await pg.close(); } catch {} }
}
console.log(await shot(s, 'm5_menu_after_links'));
// bağlantı: İletişim
const il = find('İletişim'); await tap(s, ...c(il)); await sleep(1200); console.log(await shot(s, 'm5_menu_nav_mid')); await sleep(2000); console.log(await shot(s, 'm5_menu_nav_end'));
console.log(report(s));
await s.close();
