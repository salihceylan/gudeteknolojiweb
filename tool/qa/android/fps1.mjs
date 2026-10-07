import { connect, measureFrames, sleep, adb } from './lib.mjs';
const s = await connect();
const mem = () => s.page.evaluate(() => performance.memory && [Math.round(performance.memory.usedJSHeapSize / 1e6), Math.round(performance.memory.totalJSHeapSize / 1e6)]);
console.log('mem', await mem());
console.log('fps now (ad scene)', await measureFrames(s, 3000));
console.log(adb('shell', 'cat', '/proc/meminfo').split('\n').slice(0, 3).join(' | '));
process.exit(0);
