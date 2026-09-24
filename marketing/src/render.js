// Renders the promo art in assets.html to PNG files in ../ using Playwright + Chromium.
//   NODE_PATH=$(npm root -g) node marketing/src/render.js
const path = require("path");
const { chromium } = require("playwright");

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 2000, height: 1200 } });
  await page.goto("file://" + path.join(__dirname, "assets.html"));
  // give web fonts a moment; falls back to system fonts if offline
  await page.waitForTimeout(1500);
  const outputs = [
    ["#icon", "icon_512.png"],
    ["#thumb1", "thumbnail_1_clean_everything.png"],
    ["#thumb2", "thumbnail_2_critters.png"],
    ["#thumb3", "thumbnail_3_worlds.png"],
  ];
  for (const [selector, file] of outputs) {
    await page.locator(selector).screenshot({ path: path.join(__dirname, "..", file) });
    console.log("wrote marketing/" + file);
  }
  await browser.close();
})();
