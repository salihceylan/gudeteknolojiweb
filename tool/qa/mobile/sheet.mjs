// node sheet.mjs out.png cols file1 file2 ...  (kontak sayfası)
import { chromium } from 'playwright-core';
import fs from 'node:fs';
const [out, cols, ...files] = process.argv.slice(2);
const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe' });
const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
const imgs = files.map(f => `<figure><img src="data:image/png;base64,${fs.readFileSync(f).toString('base64')}"><figcaption>${f.split(/[\/]/).pop()}</figcaption></figure>`).join('');
const w = Math.floor(1580 / cols) - 8;
await p.setContent(`<body style="margin:0;background:#888;display:flex;flex-wrap:wrap;gap:6px;padding:4px;font:11px sans-serif"><style>figure{margin:0;width:${w}px}img{width:100%;display:block}</style>${imgs}</body>`);
await p.screenshot({ path: out, fullPage: true });
await b.close();
console.log(out);
