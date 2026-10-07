import { openE, shotE, sleep } from './lib2.mjs';
for (const theme of ['dark', 'light']) {
  const s = await openE({ browser: 'edge', size: 'd1024', theme, menu: true, reduce: true });
  await sleep(2000); console.log(await shotE(s, 'panel1024')); await s.close();
}
