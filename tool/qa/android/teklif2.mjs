import { connect, shot, cdpDrag, cdpRelease, sleep } from './lib.mjs';
const s = await connect();
for (const d of [300, 560, 760]) {
  await cdpDrag(s, 206, 100, 100 + d, { steps: 15, hold: true }); await sleep(900);
  console.log(d, await shot(s, 'tk2_' + d));
  await cdpRelease(s); await sleep(3000);
  console.log(d + 'r', await shot(s, 'tk2_' + d + 'r'));
}
process.exit(0);
