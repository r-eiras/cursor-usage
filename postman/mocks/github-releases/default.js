const http = require('http');
http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method !== 'GET' || url.pathname !== '/repos/r-eiras/cursor-usage/releases/latest') {
    res.writeHead(501); res.end('Endpoint not modeled'); return;
  }
  if (req.headers.authorization || req.headers.cookie || req.headers.accept !== 'application/vnd.github+json') {
    res.writeHead(400); res.end('Unexpected client headers'); return;
  }
  const scenario = url.searchParams.get('scenario') || 'current';
  const body = {tag_name: 'v3.1.4', html_url: 'https://github.com/r-eiras/cursor-usage/releases/tag/v3.1.4', draft: false, prerelease: false};
  let code = 200;
  if (scenario === 'available') { body.tag_name = 'v3.2.0'; body.html_url = 'https://github.com/r-eiras/cursor-usage/releases/tag/v3.2.0'; }
  if (scenario === 'missing') code = 404;
  if (scenario === 'rate') code = 403;
  if (scenario === 'server') code = 500;
  if (scenario === 'foreign') body.html_url = 'https://example.test/releases/tag/v3.2.0';
  if (scenario === 'draft') body.draft = true;
  const send = () => { res.writeHead(code, {'Content-Type': 'application/json'}); res.end(scenario === 'invalid' ? '{broken' : JSON.stringify(body)); };
  if (scenario === 'slow') setTimeout(send, 1000); else send();
}).listen(process.env.PORT || 4918);
