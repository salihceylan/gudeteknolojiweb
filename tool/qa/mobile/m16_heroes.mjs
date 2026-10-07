import { openM, shot, sleep } from './lib.mjs';
const out = [];
for (const [dev, th] of [['smallPhone','dark'],['smallPhone','light'],['pixel','dark'],['phoneLandscape','light'],['tablet','light'],['tabletLandscape','light']]) {
  const s = await openM(dev, th); await sleep(2500);
  out.push(await shot(s, 'm16_hero')); await s.close();
}
console.log(out.join('\n'));
