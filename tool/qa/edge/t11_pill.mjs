import { openE, shotE, arg, sleep } from './lib2.mjs';
for (const reduce of [false, true]) {
  const s = await openE({ browser: 'edge', size: 'd1440', theme: 'dark', menu: true, reduce });
  await sleep(4500);
  console.log(reduce ? 'reduce' : 'normal', await shotE(s, reduce ? 'pill_reduce' : 'pill_normal'));
  await s.close();
}
