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

  await page.goto("/");
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(txCbor);
  await page.getByRole("button", { name: "Decode" }).click();

  await expect(
    page.getByRole("heading", { name: "Conway transaction identity" }),
  ).toBeVisible();
}

test("decodes a Conway transaction and exposes copyable identity values", async ({
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

  const txIdRow = page.locator(".identity-row", { hasText: "Transaction ID" });
  await txIdRow.getByRole("button", { name: "Copy" }).click();
  await expect(txIdRow.getByRole("button", { name: "Copied" })).toBeVisible();
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

test("opens browser rows in place without losing identity context", async ({
  page,
}) => {
  await decodeFixture(page);

  const inputsRow = page
    .locator(".browser-row")
    .filter({ has: page.locator("code", { hasText: "inputs" }) })
    .first();
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
