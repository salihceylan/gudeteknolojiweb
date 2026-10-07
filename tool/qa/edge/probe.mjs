import { enableSemantics, sleep } from './lib2.mjs';
/** Semantics'i açıp (tıklamayı bozar; sonra yenileyin) tüm düğümleri okur. */
export async function readNodes(s) {
  await enableSemantics(s.page);
  await sleep(900);
  return s.page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((n) => {
    const r = n.getBoundingClientRect();
    const text = (n.getAttribute('aria-label') || n.textContent || '').trim().split('\n')[0];
    return { label: text, role: n.getAttribute('role'), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
  }).filter((b) => b.label && b.w > 0 && b.h > 0));
}
export const find = (nodes, text) => nodes.find((n) => n.label.includes(text));
