import { launch, ready, sleep, URL0 } from './util.mjs';
const s = await launch();
const { page, log } = s;
await page.goto(URL0, { waitUntil: 'load', timeout: 90000 });
await ready(page); await sleep(3000);
console.log(await page.evaluate(() => {
  const c = [...document.querySelector('flutter-view').shadowRoot?.querySelectorAll('canvas') || document.querySelectorAll('canvas')];
  const all = []; const walk = (root) => { for (const el of root.querySelectorAll('*')) { if (el.tagName === 'CANVAS') all.push(el); if (el.shadowRoot) walk(el.shadowRoot); } }; walk(document);
  return all.map((cv) => ['webgl2', 'webgl', '2d', 'bitmaprenderer'].map((t) => { try { return t + ':' + (cv.getContext(t) ? 'ok' : 'null'); } catch (e) { return t + ':err'; } }));
}));
const gl = await page.evaluate(() => { const c = document.createElement('canvas'); const g = c.getContext('webgl2'); return g ? g.getParameter(g.VERSION) + ' / ' + (g.getExtension('WEBGL_debug_renderer_info') ? g.getParameter(g.getExtension('WEBGL_debug_renderer_info').UNMASKED_RENDERER_WEBGL) : '') : 'no webgl2'; });
console.log(gl);
await s.close();
