import { PROFILES, open as hopen, shot, sleep, scrollBy, tap, measureFrames, report, collectLabelBoxes, OUT } from '../harness.mjs';
export { PROFILES, shot, sleep, scrollBy, tap, measureFrames, report, collectLabelBoxes, OUT };
PROFILES.d1024 = { viewport: { width: 1024, height: 768 }, deviceScaleFactor: 1 };
PROFILES.d768 = { viewport: { width: 768, height: 1024 }, deviceScaleFactor: 1 };
PROFILES.d390 = { viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 };
export const URL0 = 'http://localhost:8099/';
export async function open(o = {}) {
  const t0 = Date.now();
  const q = [o.query, o.theme ? 'theme=' + o.theme : '', o.scroll != null ? 'scroll=' + o.scroll : '', o.menu ? 'menu=1' : ''].filter(Boolean).join('&');
  const s = await hopen({ browser: 'chrome', device: o.device || 'desktop', url: URL0, theme: o.theme, query: q, semantics: o.semantics });
  s.loadMs = Date.now() - t0;
  return s;
}
export const wheel = async (s, dy, n = 1, gap = 30) => { for (let i = 0; i < n; i++) { await s.page.mouse.wheel(0, dy); await sleep(gap); } };
// Çubuk/yer okuma: Flutter içindeki scroll konumu bilinmiyor; ekran görüntüsünden bakılır.

import fs from 'node:fs';
import path from 'node:path';
/** CDP screencast ile ara kareler: başlat -> {stop():[{t,file}]} (JPEG, her kare diske yazılır). */
export async function startCast(s, name, { quality = 70 } = {}) {
  const dir = path.join(OUT, `${s.browser}-${s.device}${s.theme ? '-' + s.theme : ''}`, 'cast_' + name);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  const cdp = await s.ctx.newCDPSession(s.page);
  const frames = [];
  const t0 = Date.now();
  cdp.on('Page.screencastFrame', async (f) => {
    const file = path.join(dir, String(frames.length).padStart(3, '0') + '.jpg');
    fs.writeFileSync(file, Buffer.from(f.data, 'base64'));
    frames.push({ t: Date.now() - t0, file });
    try { await cdp.send('Page.screencastFrameAck', { sessionId: f.sessionId }); } catch {}
  });
  await cdp.send('Page.startScreencast', { format: 'jpeg', quality, everyNthFrame: 1 });
  return { frames, t0, stop: async () => { try { await cdp.send('Page.stopScreencast'); } catch {} try { await cdp.detach(); } catch {} return frames; } };
}
