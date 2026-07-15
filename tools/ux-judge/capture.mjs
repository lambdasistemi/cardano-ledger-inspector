// ux-judge capture: drive the Ledger Inspector SPA through fixed user journeys and
// screenshot each, so the judge step can score the REAL rendered UI. Deterministic and
// headless; point it at prod, a preview, or a local build via UX_BASE_URL.
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const { firefox } = require("playwright");
import { mkdir, rm, writeFile } from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, "out");
const BASE =
  process.env.UX_BASE_URL ||
  "https://lambdasistemi.github.io/cardano-ledger-inspector/inspector/";
// Optional: configure a Blockfrost provider so chain-context validation runs for real
// instead of hitting the credentials wall. The key is read from the environment at run
// time (never committed); pass it via UX_BLOCKFROST_KEY. It is injected into localStorage
// (not typed into a visible field), so it never appears in a screenshot.
const BF_KEY = process.env.UX_BLOCKFROST_KEY || "";

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
      await page.locator(".example-chip").first().waitFor({ state: "visible", timeout: 30_000 });
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

// Judge the UI at multiple viewports — a real tool must hold up wide and narrow, and this
// is exactly where reflow problems (cramped forms, clipped controls, horizontal scroll)
// hide. Each scenario is captured at every viewport as <scenario>@<viewport>.png.
const VIEWPORTS = [
  { tag: "desktop-1440", width: 1440, height: 900 },
  { tag: "laptop-1024", width: 1024, height: 768 },
  { tag: "mobile-390", width: 390, height: 844 },
];

const scenarios = [
  {
    name: "01-initial",
    async run(page, tag) {
      await ready(page);
      await shot(page, `01-initial@${tag}`);
    },
  },
  {
    name: "02-decoded-valid",
    async run(page, tag) {
      await ready(page);
      await page.locator(".example-chip", { hasText: "Valid Conway transaction" }).click();
      await page.locator(".result-panel .decoded-tree-row").first().waitFor({ timeout: 60_000 });
      await shot(page, `02-decoded-valid@${tag}`);
    },
  },
  {
    name: "03-validation-broken",
    async run(page, tag) {
      await ready(page);
      await page.locator(".example-chip", { hasText: "Empty input set" }).click();
      await page.locator(".result-panel").getByRole("tab", { name: "Validation" }).click();
      await page.locator(".shacl-conformance-panel").first().waitFor({ timeout: 60_000 });
      await shot(page, `03-validation-broken@${tag}`);
    },
  },
  {
    name: "04-resolution",
    async run(page, tag) {
      await ready(page);
      await page.locator(".example-chip", { hasText: "Amaru owner-key resolution" }).click();

      const loadedHeader = page.locator(".loaded-inspector-header");
      await loadedHeader.waitFor({ state: "visible", timeout: 60_000 });
      await loadedHeader.getByRole("button", { name: "Apply selected books" }).click();

      const resultPanel = page.locator(".result-panel");
      await resultPanel.getByRole("tab", { name: "Structure" }).click();
      const structurePanel = resultPanel.getByRole("tabpanel", { name: "Structure" });
      await structurePanel
        .locator(".decoded-toolbar")
        .getByRole("button", { name: "Expand" })
        .click();

      const ownerLabel = "Amaru Network Compliance owner key";
      const resolvedSigner = structurePanel
        .locator(".decoded-tree-row--resolved")
        .filter({
          has: page.locator(".decoded-tree-key", { hasText: "Required signer" }),
        })
        .filter({
          has: page.locator(".decoded-tree-resolved-name", { hasText: ownerLabel }),
        })
        .first();
      await resolvedSigner.waitFor({ state: "visible", timeout: 60_000 });
      const resolvedLabel = await resolvedSigner.locator(".decoded-tree-resolved-name").evaluate(
        (node) =>
          Array.from(node.childNodes)
            .filter((child) => child.nodeType === Node.TEXT_NODE)
            .map((child) => child.textContent || "")
            .join("")
            .trim(),
      );
      if (resolvedLabel !== ownerLabel) {
        throw new Error(`expected exact resolved label ${ownerLabel}, got ${resolvedLabel}`);
      }
      await shot(page, `04-resolution@${tag}`);
    },
  },
];

const browser = await firefox.launch();
// Clear prior artifacts so a run's report never double-counts stale screenshots/judgments
// (e.g. single-viewport captures from an earlier run).
await rm(OUT, { recursive: true, force: true });
await mkdir(OUT, { recursive: true });
const results = [];
for (const vp of VIEWPORTS) {
  for (const s of scenarios) {
    const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
    if (BF_KEY) {
      await ctx.addInitScript((key) => {
        try {
          localStorage.setItem("persist_api_keys", "true");
          localStorage.setItem("provider", "Blockfrost");
          localStorage.setItem("network", "mainnet");
          localStorage.setItem("blockfrost_project_id", key);
        } catch (e) {
          // localStorage unavailable — ignore, scenario just runs without a provider
        }
      }, BF_KEY);
    }
    const page = await ctx.newPage();
    const label = `${s.name}@${vp.tag}`;
    try {
      await s.run(page, vp.tag);
      results.push({ name: label, ok: true });
      console.log("captured", label);
    } catch (err) {
      results.push({ name: label, ok: false, error: String(err).slice(0, 200) });
      console.log("FAILED", label, String(err).slice(0, 200));
    }
    await ctx.close();
  }
}
await browser.close();
await writeFile(path.join(OUT, "capture.json"), JSON.stringify({ base: BASE, results }, null, 2));
console.log(JSON.stringify(results, null, 2));
