const { chromium } = require('playwright');
const serve = require('./serve.js');
const fs = require('fs');
(async () => {
  const { srv, url } = await serve(__dirname);
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await (await b.newContext({ viewport: { width: 200, height: 200 } })).newPage();
  p.on('pageerror', e => console.log('pageerror', e.message)); p.on('console', m => { if (true) console.log('console', m.text().slice(0, 200)); });
  await p.goto(url + 'aobake.html');
  const t0 = Date.now();
  const res = await p.evaluate((o) => bake(o), { size: +(process.argv[2] || 1536), dirs: +(process.argv[3] || 160), wdirs: 96, debug: false });
  fs.writeFileSync('glb-in/ao.json', JSON.stringify(res));
  for (const k in res) { const a = res[k].loc, g = res[k].glob; console.log(k.padEnd(12), a.length, 'local mean', (a.reduce((s, v) => s + v, 0) / a.length).toFixed(0), ' global mean', (g.reduce((s, v) => s + v, 0) / g.length).toFixed(0)); }
  console.log('seconds', (Date.now() - t0) / 1000);
  await b.close(); srv.close();
})();
