import { connect, shot, sleep, tapCss } from './lib.mjs';
const s = await connect();
tapCss(375, 30); await sleep(2000); tapCss(117, 261); await sleep(6000);
for (let i = 0; i < 4; i++) { await shot(s, 'df_' + i); await sleep(400); }
process.exit(0);
