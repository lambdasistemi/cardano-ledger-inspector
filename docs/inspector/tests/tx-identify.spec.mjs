import { expect, test } from "@playwright/test";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "../../..");
const fixturePath =
  process.env.TX_FIXTURE_PATH ||
  path.join(
    repoRoot,
    "specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex",
  );

async function decodeFixture(page) {
  const txCbor = (await readFile(fixturePath, "utf8")).trim();

  await installClipboardMock(page);

  await page.goto("/");
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(txCbor);
  await page.getByRole("button", { name: "Decode" }).click();

  await expect(
    page.getByRole("heading", { name: "Conway transaction identity" }),
  ).toBeVisible();
}

async function installClipboardMock(page) {
  await page.addInitScript(() => {
    let copied = "";
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: {
        readText: async () => copied,
        writeText: async (value) => {
          copied = String(value);
        },
      },
    });
  });
}

test("decodes a Conway transaction and exposes compact identity values", async ({
  page,
}) => {
  await decodeFixture(page);

  await expect(page.getByText("Transaction ID", { exact: true })).toBeVisible();
  await expect(page.getByText("Body hash", { exact: true })).toBeVisible();
  await expect(page.getByText("Witnesses", { exact: true })).toBeVisible();
  await expect(
    page
      .locator(".identity-panel:not(.witness-plan):not(.validation-panel)")
      .getByText("Redeemers", { exact: true }),
  ).toBeVisible();

  await expect(
    page
      .locator(".identity-panel:not(.witness-plan):not(.validation-panel)")
      .getByRole("button"),
  ).toHaveCount(0);

  const txIdRow = page.locator(".identity-row", { hasText: "Transaction ID" });
  const txId = await txIdRow.locator("code").innerText();
  await txIdRow.locator("code").click();
  await expect(txIdRow).toHaveClass(/is-copied/);
  await expect
    .poll(() => page.evaluate(() => navigator.clipboard.readText()))
    .toBe(txId);

  const bodyHashRow = page.locator(".identity-row", { hasText: "Body hash" });
  const bodyHash = await bodyHashRow.locator("code").innerText();
  await bodyHashRow.locator("code").click();
  await expect(bodyHashRow).toHaveClass(/is-copied/);
  await expect
    .poll(() => page.evaluate(() => navigator.clipboard.readText()))
    .toBe(bodyHash);
});

test("shows transaction-derived witness plan values", async ({ page }) => {
  await decodeFixture(page);

  await expect(page.getByRole("heading", { name: "Witness plan" })).toBeVisible();
  await expect(page.getByText("Transaction-only witness plan")).toBeVisible();
  await expect(page.getByText("Present vkey witnesses")).toBeVisible();

  const redeemerRow = page
    .locator(".witness-plan .witness-row")
    .filter({ hasText: "ConwayMinting" })
    .first();
  await redeemerRow.getByRole("button", { name: "Copy" }).click();
  await expect(redeemerRow.getByRole("button", { name: "Copied" })).toBeVisible();

  const copied = await page.evaluate(() => navigator.clipboard.readText());
  expect(copied).toMatch(/^[0-9a-f]{64}$/);
});

test("surfaces ledger validation diagnostics", async ({ page }) => {
  await decodeFixture(page);

  const validationPanel = page.locator(".validation-panel");
  await expect(
    validationPanel.getByRole("heading", { name: "Ledger validation" }),
  ).toBeVisible();
  await expect(validationPanel.getByText("Status")).toBeVisible();
  await expect(validationPanel.getByText("incomplete")).toBeVisible();
  await expect(
    validationPanel.locator(".identity-section-title", {
      hasText: "Missing context",
    }),
  ).toBeVisible();
  await expect(validationPanel.getByText("Conway ledger validation")).toBeVisible();
  await expect(validationPanel.getByText("needs context")).toBeVisible();
  await expect(validationPanel.getByText("scope ledger")).toHaveCount(0);
  await expect(
    validationPanel.getByText("Ledger validation needs more explicit context"),
  ).toHaveCount(0);
  await expect(
    validationPanel.locator(".witness-row").filter({ hasText: "protocol parameters" }).first(),
  ).toBeVisible();

  const missingContextSection = validationPanel
    .locator(".witness-section")
    .filter({ hasText: "Missing context" });
  const sourceOutputRow = missingContextSection
    .locator(".witness-row")
    .filter({ hasText: "source output" })
    .first();
  await sourceOutputRow.getByRole("button", { name: "Copy" }).click();
  await expect(sourceOutputRow.getByRole("button", { name: "Copied" })).toBeVisible();

  const copied = await page.evaluate(() => navigator.clipboard.readText());
  expect(copied).toMatch(/^[0-9a-f]{64}$/);
});

test("passes producer transaction CBOR into witness planning", async ({
  page,
}) => {
  const txCbor = (await readFile(fixturePath, "utf8")).trim();
  let producerCborRequests = 0;
  let utxoRequests = 0;

  await installClipboardMock(page);
  await page.route("https://cardano-mainnet.blockfrost.io/api/v0/txs/*/cbor", async (route) => {
    producerCborRequests += 1;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ cbor: txCbor }),
    });
  });
  await page.route("https://cardano-mainnet.blockfrost.io/api/v0/txs/*/utxos", async (route) => {
    utxoRequests += 1;
    await route.abort();
  });

  await page.goto("/");
  await page
    .getByPlaceholder("mainnet... / preprod... / preview...")
    .fill("mainnet-test-project");
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(txCbor);
  await page.getByRole("button", { name: "Decode" }).click();

  await expect(
    page.getByText("Producer transaction CBOR resolved every visible transaction input"),
  ).toBeVisible();
  await expect(page.getByText("Producer txs")).toBeVisible();
  await expect(
    page.locator(".witness-plan .identity-section-title", {
      hasText: "Resolved inputs",
    }),
  ).toBeVisible();
  await expect(
    page
      .locator(".validation-panel .identity-section-title", { hasText: "Resolved inputs" })
      .first(),
  ).toBeVisible();
  expect(producerCborRequests).toBeGreaterThan(0);
  expect(utxoRequests).toBe(0);

  const resolvedRow = page
    .locator(".witness-plan .witness-row")
    .filter({ hasText: "resolved" })
    .first();
  await resolvedRow.getByRole("button", { name: "Copy" }).click();

  const copied = await page.evaluate(() => navigator.clipboard.readText());
  expect(copied).toMatch(/^[0-9a-f]{64}#[0-9]+$/);
});

test("uses the same tx CBOR provider boundary for Koios", async ({ page }) => {
  const txCbor = (await readFile(fixturePath, "utf8")).trim();
  let koiosCborRequests = 0;

  await installClipboardMock(page);
  await page.route("https://api.koios.rest/api/v1/tx_cbor", async (route) => {
    koiosCborRequests += 1;
    const requestBody = route.request().postDataJSON();
    expect(requestBody._tx_hashes).toHaveLength(1);
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([{ cbor: txCbor }]),
    });
  });

  await page.goto("/");
  await page.getByRole("radio", { name: "Koios" }).check();
  await page.getByPlaceholder("eyJhbGciOi...").fill("koios-test-token");
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(txCbor);
  await page.getByRole("button", { name: "Decode" }).click();

  await expect(
    page.getByText("Producer transaction CBOR resolved every visible transaction input"),
  ).toBeVisible();
  await expect(page.getByText("Producer txs")).toBeVisible();
  expect(koiosCborRequests).toBeGreaterThan(0);
});

test("opens browser rows in place without losing identity context", async ({
  page,
}) => {
  await decodeFixture(page);

  const inputsRow = page
    .locator(".browser-row")
    .filter({ has: page.locator("code", { hasText: "inputs" }) })
    .first();

  await expect(inputsRow.getByRole("button", { name: "Copy" })).toHaveCount(0);
  await inputsRow.locator(".browser-summary").click();
  await expect(inputsRow).toHaveClass(/is-copied/);

  await inputsRow.getByRole("button", { name: "Open" }).click();

  await expect(page.locator(".browser-children").first()).toBeVisible();
  await expect(
    page.locator(".identity-panel:not(.witness-plan):not(.validation-panel)"),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Conway transaction identity" }),
  ).toBeVisible();
});

test("keeps decoded transaction layout within the viewport", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await decodeFixture(page);

  const overflowPx = await page.evaluate(() => {
    const width = window.innerWidth;
    const scrollWidth = Math.max(
      document.documentElement.scrollWidth,
      document.body.scrollWidth,
    );
    return scrollWidth - width;
  });

  expect(overflowPx).toBeLessThanOrEqual(1);
});
