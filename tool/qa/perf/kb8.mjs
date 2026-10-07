import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page, log } = s;
await page.goto(URL0, { waitUntil: 'load' });
await ready(page); await sleep(2500);
await page.mouse.move(100, 800);
const tab = async (n) => { for (let i = 0; i < n; i++) { await page.keyboard.press('Tab'); await sleep(150); } };
const files = [];
// A: explore butonu
await tab(11); await page.keyboard.press('Enter'); await sleep(3000);
files.push(await shot(page, 'kb8_A_afterEnter'));
await tab(1); await sleep(1500);
files.push(await shot(page, 'kb8_A_tab1'));
// B: panelde Hizmetler + Enter
await page.goto(URL0, { waitUntil: 'load' }); await ready(page); await sleep(2500);
await tab(10); await page.keyboard.press('Enter'); await sleep(2000);
await tab(3); await page.keyboard.press('Enter'); await sleep(3200);
files.push(await shot(page, 'kb8_B_afterEnterHizmet'));
await tab(1); await sleep(1500);
files.push(await shot(page, 'kb8_B_tab1'));
// C: panel + Esc sonrası odak panel dışına kaçtıysa
await page.keyboard.press('Escape'); await sleep(300);
await page.goto(URL0, { waitUntil: 'load' }); await ready(page); await sleep(2500);
await tab(10); await page.keyboard.press('Enter'); await sleep(2000);
await tab(11); await sleep(800);
await page.keyboard.press('Escape'); await sleep(2000);
files.push(await shot(page, 'kb8_C_escAfterLeaving'));
console.log(files.length, log.errors);
await s.close();
