// tiny static server for the tests (the long-running one hit its time limit)
const http = require('http'), fs = require('fs'), path = require('path');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.webp': 'image/webp', '.png': 'image/png', '.glb': 'model/gltf-binary', '.bin': 'application/octet-stream' };
module.exports = (root) => new Promise((res) => {
  const srv = http.createServer((q, r) => {
    const f = path.join(root, decodeURIComponent(q.url.split('?')[0]));
    if (!f.startsWith(root)) { r.writeHead(403); return r.end(); }
    fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); return r.end(); } r.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream' }); r.end(d); });
  }).listen(0, '127.0.0.1', () => res({ srv, url: 'http://127.0.0.1:' + srv.address().port + '/' }));
});
