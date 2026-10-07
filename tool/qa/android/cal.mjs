import { connect, geom, probeTouches, touches, tapCss, sleep, state, adb, screencap } from './lib.mjs';
const s = await connect();
console.log(JSON.stringify(await geom(s)));
await probeTouches(s);
// Tema düğmesi yaklaşık (716/900*412=?)
tapCss(10, 10); await sleep(500);
console.log(JSON.stringify(await touches(s)));
