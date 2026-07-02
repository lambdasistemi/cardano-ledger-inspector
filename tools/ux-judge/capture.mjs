// ux-judge capture: drive the Ledger Inspector SPA through fixed user journeys and
// screenshot each, so the judge step can score the REAL rendered UI. Deterministic and
// headless; point it at prod, a preview, or a local build via UX_BASE_URL.
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const { firefox } = require("playwright");
import { mkdir, writeFile } from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, "out");
const BASE =
  process.env.UX_BASE_URL ||
  "https://lambdasistemi.github.io/cardano-ledger-inspector/inspector/";

// Navigate without waiting on the full 36MB-wasm `load` event; wait for the decoder to
// initialise instead, and retry — the same robustness the Playwright suite needed.
async function ready(page) {
  page.setDefaultTimeout(30_000);
  let lastErr;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      await page.goto(BASE, { waitUntil: "domcontentloaded", timeout: 60_000 });
      await page.waitForFunction(
        () => typeof globalThis.txInspectorValidateShacl === "function",
        undefined,
        { timeout: 90_000 },
      );
      await page.getByText("Paste here").first().waitFor({ state: "visible", timeout: 30_000 });
      return;
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr;
}

async function shot(page, name) {
  await page.waitForTimeout(700);
  await page.screenshot({ path: path.join(OUT, `${name}.png`), fullPage: true });
}

const scenarios = [
  {
    name: "01-initial",
    async run(page) {
      await ready(page);
      await shot(page, "01-initial");
    },
  },
  {
    name: "02-decoded-valid",
    async run(page) {
      await ready(page);
      await page.locator("md-outlined-button.example-valid").click();
      await page.locator(".result-panel .decoded-tree-row").first().waitFor({ timeout: 60_000 });
      await shot(page, "02-decoded-valid");
    },
  },
  {
    name: "03-validation-broken",
    async run(page) {
      await ready(page);
      await page.locator("md-outlined-button.example-violation").first().click();
      await page.locator(".result-panel").getByRole("tab", { name: "Validation" }).click();
      await page.locator(".shacl-conformance-panel").first().waitFor({ timeout: 60_000 });
      await shot(page, "03-validation-broken");
    },
  },
];

const browser = await firefox.launch();
await mkdir(OUT, { recursive: true });
const results = [];
for (const s of scenarios) {
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  try {
    await s.run(page);
    results.push({ name: s.name, ok: true });
    console.log("captured", s.name);
  } catch (err) {
    results.push({ name: s.name, ok: false, error: String(err).slice(0, 200) });
    console.log("FAILED", s.name, String(err).slice(0, 200));
  }
  await ctx.close();
}
await browser.close();
await writeFile(path.join(OUT, "capture.json"), JSON.stringify({ base: BASE, results }, null, 2));
console.log(JSON.stringify(results, null, 2));
