import { launch, ready, sleep, URL0, shot } from './util.mjs';
const mode = process.argv[2];
const s = await launch();
const { page, log } = s;
await page.route('**/*', (r) => {
  const u = r.request().url();
  if (mode === 'wasm' && /gstatic\.com\/flutter-canvaskit/.test(u)) return r.abort('failed');
  if (mode === 'font' && /fonts\.gstatic\.com/.test(u)) return r.abort('failed');
  return r.continue();
});
await page.goto(URL0, { waitUntil: 'load', timeout: 60000 });
if (mode === 'wasm') {
  await sleep(15000);
  console.log('boot present:', await page.evaluate(() => !!document.getElementById('boot')), 'glass-pane:', await page.evaluate(() => !!document.querySelector('flt-glass-pane')));
  console.log('body text:', await page.evaluate(() => document.body.innerText.slice(0, 100)));
  console.log(await shot(page, 'cdn_wasm_blocked'));
} else {
  await ready(page); await sleep(3000);
  console.log(await shot(page, 'cdn_font_blocked'));
}
console.log('errors', log.errors.slice(0, 5), 'failed', log.failed.slice(0, 5), 'warn', log.warnings.slice(0, 5));
await s.close();
