// Renders exported UI trees (tools/preview/ui/*.json) to PNG at their device resolution.
//   lune run tools/preview/export_ui.luau
//   NODE_PATH=$(npm root -g) node tools/preview/render_ui.js [outputDir]
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const root = __dirname;
const outDir = path.resolve(process.argv[2] || path.join(root, "..", "..", "docs", "previews", "ui"));

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  const files = fs.readdirSync(path.join(root, "ui")).filter((f) => f.endsWith(".json")).sort();
  for (const file of files) {
    const tree = JSON.parse(fs.readFileSync(path.join(root, "ui", file), "utf8"));
    const [w, h] = tree.viewport;
    // layout at the real device size, image downscaled to <= 960px wide to keep the repo light
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: Math.min(1, 960 / w) });
    page.on("pageerror", (err) => console.error("page error:", err.message));
    await page.goto("file://" + path.join(root, "ui.html"));
    await page.waitForFunction(() => window.uiReady === true);
    await page.waitForTimeout(800); // web fonts
    await page.evaluate((t) => window.renderUI(t), tree);
    await page.waitForFunction(() => window.uiDone === true);
    await page.locator("#screen").screenshot({ path: path.join(outDir, file.replace(".json", ".jpg")), type: "jpeg", quality: 72 });
    await page.close();
  }
  console.log(`rendered ${files.length} UI previews -> ${path.relative(process.cwd(), outDir)}`);
  await browser.close();
})();
