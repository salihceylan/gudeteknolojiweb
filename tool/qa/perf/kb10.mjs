import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page, log } = s;
const popups = [];
s.ctx.on('page', (p) => popups.push(p.url()));
await page.goto(URL0, { waitUntil: 'load' });
await ready(page); await sleep(2500);
await page.mouse.move(100, 800);
const tab = async (n) => { for (let i = 0; i < n; i++) { await page.keyboard.press('Tab'); await sleep(150); } };
await tab(10); await page.keyboard.press('Enter'); await sleep(2000);
await tab(3);
await page.keyboard.press('Enter'); await sleep(2500);
console.log('after Enter on link: shot', await shot(page, 'kb10_enter_link'));
await tab(4); // Teklif Pro
await page.keyboard.press('Enter'); await sleep(1500);
console.log('popups after Enter on Teklif Pro:', popups);
await page.keyboard.press('Space'); await sleep(1500);
console.log('popups after Space on Teklif Pro:', popups);
await tab(1); // acik? contacts skipped
await page.keyboard.press('Enter'); await sleep(2000);
console.log('Enter on theme seg', await shot(page, 'kb10_enter_seg'));
await page.keyboard.press('Space'); await sleep(2000);
console.log('Space on theme seg', await shot(page, 'kb10_space_seg'));
console.log(log.errors);
await s.close();
