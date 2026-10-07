import { open, sleep } from './harness.mjs';
const s = await open({ browser: 'chrome', device: 'desktop', url: 'http://localhost:8099/', theme: 'dark' });
await sleep(1500);
const info = await s.page.evaluate(() => {
  const nodes = [...document.querySelectorAll('flt-semantics')];
  return { count: nodes.length, sample: nodes.slice(0, 40).map((n) => ({ role: n.getAttribute('role'), label: n.getAttribute('aria-label'), text: (n.textContent || '').slice(0, 40) })) };
});
console.log(JSON.stringify(info, null, 1).slice(0, 3500));
await s.close();
