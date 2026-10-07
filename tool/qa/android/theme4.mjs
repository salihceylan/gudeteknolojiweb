import { connect, sleep, adb } from './lib.mjs';
const s = await connect();
console.log(await s.page.evaluate(() => matchMedia('(prefers-color-scheme: dark)').matches));
await sleep(500);
process.exit(0);
