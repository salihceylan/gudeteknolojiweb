import { connect, tapCss, sleep, adb } from './lib.mjs';
const s = await connect();
tapCss(375, 30); await sleep(2500);
tapCss(97, 497); await sleep(4000);
console.log(await (await fetch('http://127.0.0.1:9222/json')).json().then((j) => j.map((t) => t.url)));
process.exit(0);
