// Renders every exported scene (tools/preview/scenes/*.json) to PNG with three.js in headless
// Chromium (software WebGL). Usage, from the repo root:
//   lune run tools/preview/export_scenes.luau
//   (cd tools/preview && npm install)
//   NODE_PATH=$(npm root -g) node tools/preview/render.js [outputDir]
const fs = require("fs");
const http = require("http");
const path = require("path");
const { chromium } = require("playwright");

const root = __dirname;
const outDir = path.resolve(process.argv[2] || path.join(root, "..", "..", "docs", "previews"));
const WIDTH = 1600;
const HEIGHT = 900;

const TYPES = { ".html": "text/html", ".js": "text/javascript", ".json": "application/json" };
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split("?")[0]));
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404);
    return res.end();
  }
  res.writeHead(200, { "Content-Type": TYPES[path.extname(file)] || "application/octet-stream" });
  fs.createReadStream(file).pipe(res);
});

server.listen(0, "127.0.0.1", async () => {
  const port = server.address().port;
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({
    args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
  });
  const scenes = fs.readdirSync(path.join(root, "scenes")).filter((f) => f.endsWith(".json")).sort();
  for (const file of scenes) {
    const page = await browser.newPage({ viewport: { width: WIDTH, height: HEIGHT } });
    page.on("pageerror", (err) => console.error("page error:", err.message));
    await page.goto(`http://127.0.0.1:${port}/viewer.html`);
    await page.waitForFunction(() => window.viewerReady === true, null, { timeout: 30000 });
    const data = JSON.parse(fs.readFileSync(path.join(root, "scenes", file), "utf8"));
    const started = Date.now();
    await page.evaluate(([d, w, h]) => window.renderScene(d, w, h), [data, WIDTH, HEIGHT]);
    await page.waitForFunction(() => window.renderDone === true, null, { timeout: 120000 });
    const out = path.join(outDir, file.replace(".json", ".png"));
    await page.locator("canvas").screenshot({ path: out });
    console.log(`rendered ${file} (${data.parts.length} parts) in ${Date.now() - started} ms -> ${path.relative(process.cwd(), out)}`);
    await page.close();
  }
  await browser.close();
  server.close();
});
