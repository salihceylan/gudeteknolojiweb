import { connect, tapCss, sleep } from './lib.mjs';
const s = await connect();
tapCss(375, 30); await sleep(2500); tapCss(97, 497); await sleep(9000);
const j = await (await fetch('http://127.0.0.1:9222/json')).json();
console.log(j.map((t) => t.url + ' | ' + t.title));
process.exit(0);
