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

function blockfrostUtxoResponse(txHash) {
  const indexesByTx = {
    "42ceabd168faa7e7bbe10d8e72e6ba0e71886bf3537ea88bd098782e1df1c1e9": [2],
    "1ef2797c28a7679ca8e62693642513a44bed07bc37cdef73d4cd29956b4f83a5": [0],
    "87daf43c764260d9ad00342fcb0d444c15752c9215f43c6b8e74189e7ba99397": [0],
  };
  const indexes = indexesByTx[txHash] || [0];
  return {
    hash: txHash,
    inputs: [],
    outputs: indexes.map((index) => ({
      address: `addr_test1resolved${txHash.slice(0, 16)}${index}`,
      amount: [
        {
          unit: "lovelace",
          quantity: "1234567",
        },
      ],
      output_index: index,
      data_hash: null,
      inline_datum: null,
      reference_script_hash: null,
    })),
  };
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
      .locator(".identity-panel:not(.witness-plan)")
      .getByText("Redeemers", { exact: true }),
  ).toBeVisible();

  await expect(
    page.locator(".identity-panel:not(.witness-plan)").getByRole("button"),
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

test("passes resolved Blockfrost input context into witness planning", async ({
  page,
}) => {
  const txCbor = (await readFile(fixturePath, "utf8")).trim();

  await installClipboardMock(page);
  await page.route("https://cardano-mainnet.blockfrost.io/api/v0/txs/*/utxos", async (route) => {
    const match = route.request().url().match(/\/txs\/([^/]+)\/utxos$/);
    const txHash = match ? match[1] : "";
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(blockfrostUtxoResponse(txHash)),
    });
  });

  await page.goto("/");
  await page
    .getByPlaceholder("mainnet... / preprod... / preview...")
    .fill("mainnet-test-project");
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(txCbor);
  await page.getByRole("button", { name: "Decode" }).click();

  await expect(
    page.getByText("UTxO context was supplied for every visible transaction input"),
  ).toBeVisible();
  await expect(page.getByText("Context UTxOs")).toBeVisible();
  await expect(
    page.locator(".identity-section-title", { hasText: "Resolved inputs" }),
  ).toBeVisible();

  const resolvedRow = page
    .locator(".witness-plan .witness-row")
    .filter({ hasText: "resolved" })
    .first();
  await resolvedRow.getByRole("button", { name: "Copy" }).click();

  const copied = await page.evaluate(() => navigator.clipboard.readText());
  expect(copied).toMatch(/^[0-9a-f]{64}#[0-9]+$/);
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
  await expect(page.locator(".identity-panel:not(.witness-plan)")).toBeVisible();
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
