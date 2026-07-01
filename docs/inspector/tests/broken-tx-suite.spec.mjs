// Verifies the "meaningfully wrong" example transactions actually fire their
// target Class-A / network SHACL shapes through the REAL pipeline:
// decode CBOR -> projected cardano: RDF -> SHACL. Unlike the crafted-Turtle
// Class-A test, this proves the decoder projects enough for each shape to fire
// on a genuinely decoded transaction. Doubles as the regression gate for the
// broken-tx examples picker.
import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "../../..");
const shapesPath = path.join(repoRoot, "docs/inspector/protocols/cardano-rdf/shapes.ttl");
const brokenDir = path.join(
  repoRoot,
  "specs/001-ledger-functional-layer/fixtures/broken",
);
const manifest = JSON.parse(readFileSync(path.join(brokenDir, "manifest.json"), "utf8"));
const shapes = readFileSync(shapesPath, "utf8");

// Navigate without waiting for the ~36MB wasm to finish the `load` event
// (that is what hangs under runner load); wait explicitly for the decoder to
// initialise instead, and retry the navigation a couple of times to stay robust.
async function gotoApp(page) {
  page.setDefaultTimeout(30_000);
  let lastErr;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      await page.goto("/", { waitUntil: "domcontentloaded", timeout: 60_000 });
      await page.waitForFunction(
        () => typeof globalThis.txInspectorValidateShacl === "function",
        undefined,
        { timeout: 90_000 },
      );
      return;
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr;
}

async function decodeHex(page, hex) {
  await gotoApp(page);
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(hex);
  await page.getByRole("button", { name: "Decode" }).click();
  const resultPanel = page.locator(".result-panel");
  await expect(
    resultPanel.getByRole("tab", { name: "Structure" }),
  ).toHaveAttribute("aria-selected", "true");
  await resultPanel.getByRole("tab", { name: "Graph / RDF" }).click();
  const panel = resultPanel.getByRole("tabpanel", { name: "Graph / RDF" });
  await expect(panel).toBeVisible();
  return panel.locator(".rdf-turtle").innerText();
}

for (const ex of manifest) {
  test(`${ex.slug} decodes and fires ${ex.shape}`, async ({ page }) => {
    test.setTimeout(180_000);
    const hex = readFileSync(path.join(brokenDir, `${ex.slug}.hex`), "utf8").trim();
    const turtle = await decodeHex(page, hex);
    const report = await page.evaluate(
      ({ data, s }) => globalThis.txInspectorValidateShacl(data, s),
      { data: turtle, s: shapes },
    );
    const messages = (report.violations || []).map((v) => v.message || "").join(" | ");
    expect(report.conforms, `${ex.slug} should be non-conforming; messages: ${messages}`).toBe(
      false,
    );
    expect(
      messages.includes(ex.shape),
      `${ex.slug} expected shape "${ex.shape}"; got: ${messages}`,
    ).toBe(true);
  });
}

test("examples picker loads and decodes a broken tx end to end", async ({ page }) => {
  test.setTimeout(180_000);
  await gotoApp(page);
  await page.getByRole("button", { name: /Empty input set/ }).click();
  const resultPanel = page.locator(".result-panel");
  await expect(
    resultPanel.getByRole("tab", { name: "Structure" }),
  ).toHaveAttribute("aria-selected", "true");
  await resultPanel.getByRole("tab", { name: "Validation" }).click();
  await expect(page.locator(".shacl-conformance-panel")).toContainText(
    "InputSetEmptyUTxO",
  );
});
