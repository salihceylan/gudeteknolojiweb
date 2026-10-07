import { open, shot, sleep, report } from './common.mjs';
const th = process.argv[2] || 'dark';
const list = (process.argv[3] || '0.2375,0.475,0.7125,0.95').split(',');
for (const sc of list) {
  const s = await open({ theme: th, scroll: sc });
  await sleep(2500);
  console.log(th, sc, await shot(s, `t5i_${sc}`));
  if (s.errors.length) console.log(report(s));
  await s.close();
}
