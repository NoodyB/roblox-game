// Composes marketing thumbnails from real geometry renders (docs/previews/*.png).
//   NODE_PATH=$(npm root -g) node marketing/src/render_real.js
const path = require("path");
const { chromium } = require("playwright");
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 2200 } });
  await page.goto("file://" + path.join(__dirname, "real_thumbs.html"));
  await page.waitForTimeout(1500);
  for (const [sel, file] of [["#real1", "thumbnail_4_real_squad.png"], ["#real2", "thumbnail_5_real_golden.png"]]) {
    await page.locator(sel).screenshot({ path: path.join(__dirname, "..", file) });
    console.log("wrote marketing/" + file);
  }
  await browser.close();
})();
