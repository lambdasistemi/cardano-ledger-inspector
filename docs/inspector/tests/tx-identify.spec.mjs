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
const signingIntentFixturePath = path.join(
  repoRoot,
  "specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex",
);
const validationFixturePath = path.join(
  repoRoot,
  "specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json",
);

async function loadValidationContext() {
  const request = JSON.parse(await readFile(validationFixturePath, "utf8"));
  return request.args.context;
}

function producerCbor(context, txHash, fallback) {
  return context.producer_txs?.[txHash]?.tx_cbor || fallback;
}

async function mockKoiosValidationContext(page, validationContext) {
  await page.route("https://api.koios.rest/api/v1/tip", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([
        {
          abs_slot: Number(validationContext.slot),
          epoch_no: Number(validationContext.epoch),
        },
      ]),
    });
  });
  await page.route("https://api.koios.rest/api/v1/cli_protocol_params", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(validationContext.protocol_parameters),
    });
  });
}

function blockfrostParamsFromLedger(params) {
  const pool = params.poolVotingThresholds || {};
  const drep = params.dRepVotingThresholds || {};
  return {
    min_fee_a: params.txFeePerByte,
    min_fee_b: params.txFeeFixed,
    max_block_size: params.maxBlockBodySize,
    max_tx_size: params.maxTxSize,
    max_block_header_size: params.maxBlockHeaderSize,
    key_deposit: String(params.stakeAddressDeposit),
    pool_deposit: String(params.stakePoolDeposit),
    e_max: params.poolRetireMaxEpoch,
    n_opt: params.stakePoolTargetNum,
    a0: params.poolPledgeInfluence,
    rho: params.monetaryExpansion,
    tau: params.treasuryCut,
    protocol_major_ver: params.protocolVersion?.major,
    protocol_minor_ver: params.protocolVersion?.minor,
    min_pool_cost: String(params.minPoolCost),
    coins_per_utxo_size: String(params.utxoCostPerByte),
    cost_models_raw: params.costModels,
    price_mem: params.executionUnitPrices?.priceMemory,
    price_step: params.executionUnitPrices?.priceSteps,
    max_tx_ex_mem: String(params.maxTxExecutionUnits?.memory),
    max_tx_ex_steps: String(params.maxTxExecutionUnits?.steps),
    max_block_ex_mem: String(params.maxBlockExecutionUnits?.memory),
    max_block_ex_steps: String(params.maxBlockExecutionUnits?.steps),
    max_val_size: String(params.maxValueSize),
    collateral_percent: params.collateralPercentage,
    max_collateral_inputs: params.maxCollateralInputs,
    pvt_motion_no_confidence: pool.motionNoConfidence,
    pvt_committee_normal: pool.committeeNormal,
    pvt_committee_no_confidence: pool.committeeNoConfidence,
    pvt_hard_fork_initiation: pool.hardForkInitiation,
    pvt_p_p_security_group: pool.ppSecurityGroup,
    dvt_motion_no_confidence: drep.motionNoConfidence,
    dvt_committee_normal: drep.committeeNormal,
    dvt_committee_no_confidence: drep.committeeNoConfidence,
    dvt_update_to_constitution: drep.updateToConstitution,
    dvt_hard_fork_initiation: drep.hardForkInitiation,
    dvt_p_p_network_group: drep.ppNetworkGroup,
    dvt_p_p_economic_group: drep.ppEconomicGroup,
    dvt_p_p_technical_group: drep.ppTechnicalGroup,
    dvt_p_p_gov_group: drep.ppGovGroup,
    dvt_treasury_withdrawal: drep.treasuryWithdrawal,
    committee_min_size: String(params.committeeMinSize),
    committee_max_term_length: String(params.committeeMaxTermLength),
    gov_action_lifetime: String(params.govActionLifetime),
    gov_action_deposit: String(params.govActionDeposit),
    drep_deposit: String(params.dRepDeposit),
    drep_activity: String(params.dRepActivity),
    min_fee_ref_script_cost_per_byte: params.minFeeRefScriptCostPerByte,
  };
}

async function decodeFixture(page, txFixturePath = fixturePath) {
  const txCbor = (await readFile(txFixturePath, "utf8")).trim();
  const validationContext = await loadValidationContext();

  await installClipboardMock(page);
  await mockKoiosValidationContext(page, validationContext);

  await page.goto("/");
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(txCbor);
  await page.getByRole("button", { name: "Decode" }).click();

  await expect(
    page.getByRole("heading", { name: "Conway transaction identity" }),
  ).toBeVisible();
}

async function expectInFirstViewport(locator) {
  await expect(locator).toBeVisible();
  const box = await locator.evaluate((element) => {
    const rect = element.getBoundingClientRect();
    return {
      top: rect.top,
      bottom: rect.bottom,
      innerHeight: window.innerHeight,
    };
  });

  expect(box.top).toBeGreaterThanOrEqual(0);
  expect(box.bottom).toBeLessThanOrEqual(box.innerHeight);
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

test("renders the transaction RDF graph after decode", async ({ page }) => {
  await decodeFixture(page);

  const rdfPanel = page.locator(".rdf-panel");
  await expect(
    rdfPanel.getByRole("heading", { name: "Transaction RDF graph" }),
  ).toBeVisible();
  await expect(rdfPanel.getByText("text/turtle", { exact: true })).toBeVisible();

  const turtle = rdfPanel.locator(".rdf-turtle");
  await expect(turtle).toContainText("@prefix cardano:");
  await expect(turtle).toContainText("cardano:Transaction");
});

test("keeps signer-critical intent visible in the first viewport", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 });
  await decodeFixture(page, signingIntentFixturePath);

  const intentPanel = page.locator(".intent-panel");
  const intentMetric = (label, value) =>
    intentPanel
      .locator(".metric-card", { hasText: label })
      .getByText(value, { exact: true });
  await expect(intentPanel.getByRole("heading", { name: "Signing summary" })).toBeVisible();
  await expectInFirstViewport(intentPanel.getByText("Swap ADA<->USDM", { exact: true }));
  await expectInFirstViewport(
    intentPanel.getByText("Required to pay Antithesis as vendor"),
  );
  await expectInFirstViewport(intentMetric("Signer net ADA", "unknown"));
  await expectInFirstViewport(intentMetric("Missing signers", "2 missing required signers"));
  await expectInFirstViewport(intentMetric("Redeemers", "2 redeemers"));
  await expectInFirstViewport(intentMetric("Withdrawals", "1 withdrawal"));
  await expectInFirstViewport(intentMetric("Mint/burn", "No mint/burn"));
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
    validationPanel.getByText("Missing source outputs (3)."),
  ).toBeVisible();
  const missingContextSection = validationPanel
    .locator(".witness-section")
    .filter({ hasText: "Missing context" });
  await expect(
    missingContextSection.locator(".witness-row").filter({ hasText: "protocol parameters" }),
  ).toHaveCount(0);
  await expect(validationPanel.getByText("koios.tip+cli_protocol_params")).toBeVisible();
  await expect(
    validationPanel
      .locator(".witness-section", { hasText: "Checks" })
      .getByRole("button", { name: "Copy" }),
  ).toHaveCount(0);

  const sourceOutputRow = missingContextSection
    .locator(".witness-row")
    .filter({ hasText: "source output" })
    .first();
  await sourceOutputRow.getByRole("button", { name: "Copy" }).click();
  await expect(sourceOutputRow.getByRole("button", { name: "Copied" })).toBeVisible();

  const copied = await page.evaluate(() => navigator.clipboard.readText());
  expect(copied).toMatch(/^[0-9a-f]{64}$/);
});

test("keeps copy controls off non-value missing context rows", async ({ page }) => {
  const txCbor = (await readFile(fixturePath, "utf8")).trim();

  await installClipboardMock(page);
  await page.route("https://api.koios.rest/api/v1/tip", async (route) => {
    await route.abort();
  });
  await page.route("https://api.koios.rest/api/v1/cli_protocol_params", async (route) => {
    await route.abort();
  });

  await page.goto("/");
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(txCbor);
  await page.getByRole("button", { name: "Decode" }).click();

  const missingContextSection = page
    .locator(".validation-panel .witness-section")
    .filter({ hasText: "Missing context" });
  const protocolParametersRow = missingContextSection
    .locator(".witness-row")
    .filter({ hasText: "protocol parameters" })
    .first();
  await expect(protocolParametersRow).toBeVisible();
  await expect(protocolParametersRow.getByRole("button", { name: "Copy" })).toHaveCount(0);

  const sourceOutputRow = missingContextSection
    .locator(".witness-row")
    .filter({ hasText: "source output" })
    .first();
  await expect(sourceOutputRow.getByRole("button", { name: "Copy" })).toBeVisible();
});

test("passes producer transaction CBOR into witness planning", async ({
  page,
}) => {
  const txCbor = (await readFile(fixturePath, "utf8")).trim();
  const validationContext = await loadValidationContext();
  let producerCborRequests = 0;
  let utxoRequests = 0;
  let latestBlockRequests = 0;
  let protocolParameterRequests = 0;

  await installClipboardMock(page);
  await page.route("https://cardano-mainnet.blockfrost.io/api/v0/txs/*/cbor", async (route) => {
    producerCborRequests += 1;
    const txHash = route.request().url().match(/\/txs\/([0-9a-f]+)\/cbor/)?.[1];
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ cbor: producerCbor(validationContext, txHash, txCbor) }),
    });
  });
  await page.route("https://cardano-mainnet.blockfrost.io/api/v0/blocks/latest", async (route) => {
    latestBlockRequests += 1;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        slot: Number(validationContext.slot),
        epoch: Number(validationContext.epoch),
      }),
    });
  });
  await page.route(
    "https://cardano-mainnet.blockfrost.io/api/v0/epochs/latest/parameters",
    async (route) => {
      protocolParameterRequests += 1;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(
          blockfrostParamsFromLedger(validationContext.protocol_parameters),
        ),
      });
    },
  );
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
  await expect(
    page
      .locator(".validation-panel .metric-card", { hasText: "Status" })
      .getByText("valid", { exact: true }),
  ).toBeVisible();
  expect(producerCborRequests).toBeGreaterThan(0);
  expect(latestBlockRequests).toBe(1);
  expect(protocolParameterRequests).toBe(1);
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
  const validationContext = await loadValidationContext();
  let koiosCborRequests = 0;
  let koiosTipRequests = 0;
  let koiosPParamRequests = 0;

  await installClipboardMock(page);
  await page.route("https://api.koios.rest/api/v1/tx_cbor", async (route) => {
    koiosCborRequests += 1;
    const requestBody = route.request().postDataJSON();
    expect(requestBody._tx_hashes).toHaveLength(1);
    const txHash = requestBody._tx_hashes[0];
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([{ cbor: producerCbor(validationContext, txHash, txCbor) }]),
    });
  });
  await page.route("https://api.koios.rest/api/v1/tip", async (route) => {
    koiosTipRequests += 1;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([
        {
          abs_slot: Number(validationContext.slot),
          epoch_no: Number(validationContext.epoch),
        },
      ]),
    });
  });
  await page.route("https://api.koios.rest/api/v1/cli_protocol_params", async (route) => {
    koiosPParamRequests += 1;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(validationContext.protocol_parameters),
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
  await expect(
    page
      .locator(".validation-panel .metric-card", { hasText: "Status" })
      .getByText("valid", { exact: true }),
  ).toBeVisible();
  expect(koiosCborRequests).toBeGreaterThan(0);
  expect(koiosTipRequests).toBe(1);
  expect(koiosPParamRequests).toBe(1);
});

test("routes Blockfrost-shaped keys away from Koios auth", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("radio", { name: "Koios" }).check();
  await page.getByPlaceholder("eyJhbGciOi...").fill("mainnet-test-project");

  await expect(page.getByRole("radio", { name: "Blockfrost" })).toBeChecked();
  await expect(page.getByPlaceholder("mainnet... / preprod... / preview...")).toHaveValue(
    "mainnet-test-project",
  );
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
