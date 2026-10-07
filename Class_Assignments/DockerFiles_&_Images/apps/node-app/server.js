const express = require("express");
const app = express();
const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.send(`<h1>Hello World from Docker multi-stage build</h1>
<p>Node.js ${process.version} + Express</p>`);
});

app.listen(PORT, () => console.log(`Node app on port ${PORT}`));
