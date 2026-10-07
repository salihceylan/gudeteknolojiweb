export * from '../harness.mjs';
import { open, sleep, shot } from '../harness.mjs';
export const URL = 'http://localhost:8099/';
export async function openM(device, theme, query = '') {
  return open({ device, theme, url: URL, query: ['theme=' + theme, query].filter(Boolean).join('&') });
}
export async function cdp(s) { if (!s._cdp) s._cdp = await s.ctx.newCDPSession(s.page); return s._cdp; }
/** Parmak sürükleme: (x0,y0)->(x1,y1) n adımda; hold=true ise parmak kalkmaz (yukarı çağıran touchEnd'i çağırır). */
export async function dragStart(s, x, y) { const c = await cdp(s); await c.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] }); }
export async function dragMove(s, x, y) { const c = await cdp(s); await c.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y }] }); }
export async function dragEnd(s) { const c = await cdp(s); await c.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); }
export async function drag(s, x0, y0, x1, y1, { steps = 12, stepMs = 30, hold = false } = {}) {
  await dragStart(s, x0, y0);
  for (let i = 1; i <= steps; i++) { await dragMove(s, x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps); await sleep(stepMs); }
  if (!hold) await dragEnd(s);
}
export async function scrollOffsetProbe(s) { return null; }
/** Semantics'i dayanıklı açar (Android UA'da tek tıklama yetmeyebilir). Düğüm sayısını döndürür. */
export async function semOn(s) {
  const n = () => s.page.evaluate(() => document.querySelectorAll('flt-semantics').length);
  for (let i = 0; i < 5; i++) {
    if (await n() > 0) return n();
    const vp = s.page.viewportSize(); await dragStart(s, vp.width / 2, vp.height / 2); await sleep(80); await dragEnd(s); await sleep(700);
    if (await n() > 0) break;
    await s.page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await sleep(900);
  }
  await sleep(600);
  return n();
}
export async function boxesNow(s) {
  return s.page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((n) => {
    const r = n.getBoundingClientRect();
    const text = (n.getAttribute('aria-label') || n.textContent || '').trim().split('\n')[0];
    return { label: text.slice(0, 44), role: n.getAttribute('role'), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
  }).filter((b) => b.label && b.w > 0 && b.h > 0));
}
