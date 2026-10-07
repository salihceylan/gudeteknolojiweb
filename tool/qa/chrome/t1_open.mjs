import { open, shot, sleep, report, measureFrames, PROFILES } from './common.mjs';
const devs = [['desktop1080','1920x1080'],['desktop','1440x900'],['laptop','1280x720'],['d1024','1024x768']];
const which = process.argv[2] ? [process.argv[2]] : ['dark','light'];
const only = process.argv[3];
for (const th of which) for (const [d, n] of devs) { if (only && only !== d) continue;
  const s = await open({ device: d, theme: th });
  await sleep(1500);
  const f = await shot(s, `r2_open_${n}`);
  const fr = await measureFrames(s, 1500);
  console.log(th, n, 'load', s.loadMs, JSON.stringify(fr), f);
  console.log(report(s));
  await s.close();
}
