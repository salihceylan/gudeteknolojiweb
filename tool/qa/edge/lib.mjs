import * as H from '../harness.mjs';
export * from '../harness.mjs';
H.PROFILES.d1024 = { viewport: { width: 1024, height: 768 }, deviceScaleFactor: 1 };
export const URL = 'http://localhost:8099/';
export const SIZES = { d1440: 'desktop', d1024: 'd1024' };
// Ortam: edge veya chrome; theme: dark|light. Tema URL parametresiyle ayarlanır (kaydedilir).
export async function openEnv({ browser = 'edge', device = 'desktop', theme = 'dark', query = '' } = {}) {
  const q = `theme=${theme}` + (query ? '&' + query : '');
  const s = await H.open({ browser, device, url: URL, theme, query: q });
  return s;
}
