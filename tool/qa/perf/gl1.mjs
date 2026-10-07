import { launch, ready, sleep, URL0, shot } from './util.mjs';
const s = await launch();
const { page, log } = s;
await page.goto(URL0 + '?scroll=1', { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(3500);
const info = await page.evaluate(() => {
  const found = [];
  const walk = (root) => { for (const el of root.querySelectorAll('*')) { if (el.tagName === 'CANVAS') found.push(el); if (el.shadowRoot) walk(el.shadowRoot); } };
  walk(document);
  window.__cv = found;
  return found.map((c) => ({ w: c.width, h: c.height, style: c.getAttribute('style')?.slice(0, 80) }));
});
console.log('canvases', JSON.stringify(info));
const a = await shot(page, 'gl_before');
const r = await page.evaluate(() => {
  const c = window.__cv[0]; const gl = c.getContext('webgl2') || c.getContext('webgl');
  if (!gl) return 'no gl ctx';
  const ext = gl.getExtension('WEBGL_lose_context'); if (!ext) return 'no ext';
  window.__ext = ext; window.__lost = 0; window.__rest = 0;
  c.addEventListener('webglcontextlost', () => window.__lost++); c.addEventListener('webglcontextrestored', () => window.__rest++);
  ext.loseContext(); return 'lost requested';
});
console.log(r);
await sleep(2500);
const b = await shot(page, 'gl_lost');
console.log('events', await page.evaluate(() => [window.__lost, window.__rest]));
await page.evaluate(() => window.__ext?.restoreContext());
await sleep(4000);
const c2 = await shot(page, 'gl_restored');
console.log('events', await page.evaluate(() => [window.__lost, window.__rest]));
// etkileşim sürüyor mu: tema düğmesi
await page.mouse.move(1340, 32); await sleep(100); await page.mouse.down(); await page.mouse.up(); await sleep(3000);
const d = await shot(page, 'gl_restored_themetoggle');
console.log('errors', log.errors.slice(0, 6), 'warn', log.warnings.slice(0, 6));
await s.close();
