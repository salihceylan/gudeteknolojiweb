import { connect, geom, shot, cdpDrag, sleep, rep } from './lib.mjs';
const s = await connect();
console.log(JSON.stringify(await geom(s)));
await sleep(3000);
console.log('top', await shot(s, 'ls_00'));
const g = await geom(s);
const h = g.ih;
for (let i = 1; i <= 7; i++) {
  await cdpDrag(s, g.iw / 2, h * 0.8, h * 0.8 - Math.min(h * 0.6, 300), { steps: 14, stepMs: 30 });
  await sleep(3500);
  console.log(i, await shot(s, 'ls_0' + i));
}
console.log(rep(s));
process.exit(0);
