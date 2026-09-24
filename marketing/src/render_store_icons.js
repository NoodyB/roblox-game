// Renders the game pass / developer product icons in store_icons.html to 512x512 PNGs in
// marketing/store_icons/. Optional second arg: write a contact sheet (with the circle crop Roblox
// uses for game passes) to that path.
//   NODE_PATH=$(npm root -g) node marketing/src/render_store_icons.js [sheet.png]
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

(async () => {
  const outDir = path.join(__dirname, "..", "store_icons");
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 512, height: 512 } });
  await page.goto("file://" + path.join(__dirname, "store_icons.html"));
  await page.waitForFunction(() => window.ready === true);
  await page.waitForTimeout(1500); // web font
  const names = await page.evaluate(() => window.iconNames);
  for (const name of names) {
    await page.evaluate((n) => window.showIcon(n), name);
    await page.locator("#stage").screenshot({ path: path.join(outDir, name + ".png") });
    console.log("wrote marketing/store_icons/" + name + ".png");
  }
  const sheet = process.argv[2];
  if (sheet) {
    const cells = names
      .map((n) => {
        const src = "data:image/png;base64," + fs.readFileSync(path.join(outDir, n + ".png")).toString("base64");
        const round = n.startsWith("pass_") ? "border-radius:50%" : "border-radius:24px";
        return `<figure style="margin:0;text-align:center;font:600 14px sans-serif;color:#ddd"><img src="${src}" style="width:220px;height:220px;${round}"><figcaption>${n}</figcaption></figure>`;
      })
      .join("");
    const sheetPage = await browser.newPage({ viewport: { width: 1240, height: 560 } });
    await sheetPage.setContent(`<body style="margin:0;background:#2b2d31;padding:16px;display:grid;grid-template-columns:repeat(5,220px);gap:18px 20px">${cells}</body>`);
    await sheetPage.waitForTimeout(300);
    await sheetPage.screenshot({ path: sheet, fullPage: true });
  }
  await browser.close();
})();
