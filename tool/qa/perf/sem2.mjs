import { launch, ready, sleep, URL0 } from './util.mjs';
const q = process.argv[2] || '';
const s = await launch();
const { page, log } = s;
await page.goto(URL0 + q, { waitUntil: 'load' });
await ready(page); await sleep(3000);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForSelector('flt-semantics', { timeout: 8000 });
await sleep(2000);
const html = await page.evaluate(() => document.querySelector('flt-semantics-host')?.outerHTML.length);
console.log('len', html);
const h = await page.evaluate(() => {
  const strip = (n, d=0) => { 
    if (n.nodeType === 3) return n.textContent.trim() ? '"' + n.textContent.trim().slice(0,70) + '"' : '';
    if (n.nodeType !== 1) return '';
    const r = n.getBoundingClientRect();
    const attrs = ['role','aria-label','aria-level','aria-hidden','tabindex','aria-live','aria-disabled'].map(a => n.getAttribute(a) != null ? `${a}=${n.getAttribute(a)}` : '').filter(Boolean).join(' ');
    const kids = [...n.childNodes].map(c => strip(c, d+1)).filter(Boolean);
    if (n.tagName === 'FLT-SEMANTICS' || n.tagName==='FLT-SEMANTICS-CONTAINER') {
      const t = `${n.tagName.replace('FLT-','')}${attrs? ' {'+attrs+'}':''} @${Math.round(r.x)},${Math.round(r.y)} ${Math.round(r.width)}x${Math.round(r.height)}`;
      return '  '.repeat(d) + t + (kids.length ? '\n' + kids.join('\n') : '');
    }
    return '  '.repeat(d) + (kids.join(' ') || '');
  };
  return strip(document.querySelector('flt-semantics-host'));
});
console.log(h.slice(0, 9000));
await s.close();
