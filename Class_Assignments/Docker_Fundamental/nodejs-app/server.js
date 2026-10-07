// Minimal Node.js web server using only the built-in http module (no npm packages needed).
const http = require("http");
const PORT = process.env.PORT || 3000;

const page = `<!DOCTYPE html>
<html><head><title>Node.js app</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:15%">
  <h1>Hello World</h1>
  <p>from a Node.js ${process.version} container</p>
</body></html>`;

http.createServer((req, res) => {
  console.log(`${req.method} ${req.url}`);
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end(page);
}).listen(PORT, () => console.log(`Node.js app listening on port ${PORT}`));
