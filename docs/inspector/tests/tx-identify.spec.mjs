import { expect, test } from "@playwright/test";
import { createServer } from "node:http";
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
const amaruJournalFixturePath = path.join(
  repoRoot,
  "docs/inspector/protocols/amaru-treasury/journal-2026.json",
);
const sundaeBlueprintFixturePath = path.join(
  repoRoot,
  "docs/inspector/protocols/sundaeswap-v3/plutus.json",
);
const packagedSiteDir = path.resolve(
  process.cwd(),
  process.env.TX_INSPECTOR_SITE_DIR || "result",
);
const previewPrefix = "/lambdasistemi/cardano-ledger-inspector/pr-99/";
const violatingShaclShapes = `
@prefix cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#> .
@prefix sh: <http://www.w3.org/ns/shacl#> .

cardano:TransactionShape
  a sh:NodeShape ;
  sh:targetClass cardano:Transaction ;
  sh:property cardano:RequiresSentinelShape .

cardano:RequiresSentinelShape
  sh:path cardano:requiresSentinel ;
  sh:minCount 1 ;
  sh:message "Transactions must include sentinel off-spec marker." .
`;

function contentTypeFor(filePath) {
  if (filePath.endsWith(".html")) return "text/html";
  if (filePath.endsWith(".js")) return "text/javascript";
  if (filePath.endsWith(".css")) return "text/css";
  if (filePath.endsWith(".wasm")) return "application/wasm";
  return "application/octet-stream";
}

async function withPrefixedInspectorSite(callback) {
  const server = createServer(async (request, response) => {
    try {
      const url = new URL(request.url || "/", "http://127.0.0.1");
      if (!url.pathname.startsWith(previewPrefix)) {
        response.writeHead(404).end("outside preview prefix");
        return;
      }

      let relativePath = decodeURIComponent(url.pathname.slice(previewPrefix.length));
      if (relativePath === "" || relativePath.endsWith("/")) {
        relativePath += "index.html";
      } else if (["inspect", "settings", "library"].includes(relativePath)) {
        relativePath += "/index.html";
      }

      const targetPath = path.normalize(path.join(packagedSiteDir, relativePath));
      if (!targetPath.startsWith(packagedSiteDir + path.sep)) {
        response.writeHead(403).end("outside site root");
        return;
      }

      const body = await readFile(targetPath);
      response.writeHead(200, { "content-type": contentTypeFor(targetPath) });
      response.end(body);
    } catch {
      response.writeHead(404).end("not found");
    }
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();
  try {
    await callback(`http://127.0.0.1:${port}${previewPrefix}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

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

async function decodeFixtureAt(page, route, txFixturePath = fixturePath) {
  const txCbor = (await readFile(txFixturePath, "utf8")).trim();
  const validationContext = await loadValidationContext();

  await installClipboardMock(page);
  await mockKoiosValidationContext(page, validationContext);

  await page.goto(route);
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(txCbor);
  await page.getByRole("button", { name: "Decode" }).click();

  await expect(
    page.getByRole("heading", { name: "Conway transaction identity" }),
  ).toBeVisible();
}

async function decodeFixture(page, txFixturePath = fixturePath) {
  await decodeFixtureAt(page, "/", txFixturePath);
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

async function expectColorToken(page, locator, property, tokenName) {
  const values = await locator.evaluate(
    (element, { property, tokenName }) => {
      const probe = document.createElement("span");
      probe.style.color = `var(${tokenName})`;
      document.body.append(probe);
      const tokenValue = getComputedStyle(probe).color;
      probe.remove();

      return {
        actual: getComputedStyle(element)[property],
        tokenValue,
      };
    },
    { property, tokenName },
  );

  expect(values.actual).toBe(values.tokenValue);
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

test("MD3 shell routes topbar nav and theme toggle", async ({ page }) => {
  await page.goto("/inspect");

  const topbar = page.getByRole("banner");
  const navigation = topbar.getByRole("navigation");
  await expect(
    topbar.getByText("Cardano transaction inspector", { exact: true }),
  ).toBeVisible();
  await expect(navigation.getByRole("link", { name: "Inspect" })).toBeVisible();
  await expect(navigation.getByRole("link", { name: "Settings" })).toBeVisible();
  await expect(navigation.getByRole("link", { name: "Library" })).toBeVisible();
  await expect(page.getByRole("radio", { name: "CBOR hex" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Decode" })).toBeVisible();

  const initialTheme = await page.evaluate(
    () => document.documentElement.dataset.theme,
  );
  await topbar.getByRole("button", { name: "Toggle theme" }).click();
  await expect
    .poll(() => page.evaluate(() => document.documentElement.dataset.theme))
    .not.toBe(initialTheme);

  await navigation.getByRole("link", { name: "Settings" }).click();
  await expect(page).toHaveURL(/\/settings$/);
  await expect(page.getByRole("heading", { name: "Settings" })).toBeVisible();
  await expect(page.getByText("Settings placeholder", { exact: true })).toBeVisible();

  await navigation.getByRole("link", { name: "Library" }).click();
  await expect(page).toHaveURL(/\/library$/);
  await expect(page.getByRole("heading", { name: "Library" })).toBeVisible();
  await expect(page.getByText("Library placeholder", { exact: true })).toBeVisible();
});

test("MD3 shell keeps route navigation inside deployed subpaths", async ({
  page,
}) => {
  await withPrefixedInspectorSite(async (baseUrl) => {
    await page.goto(`${baseUrl}settings/`);
    await expect(page.getByRole("heading", { name: "Settings" })).toBeVisible();
    expect(page.url().startsWith(`${baseUrl}settings/`)).toBe(true);

    const navigation = page.getByRole("banner").getByRole("navigation");
    await navigation.getByRole("link", { name: "Library" }).click();
    await expect(page.getByRole("heading", { name: "Library" })).toBeVisible();
    expect(page.url().startsWith(`${baseUrl}library`)).toBe(true);
    expect(new URL(page.url()).pathname).not.toBe("/library");

    await page.reload();
    await expect(page.getByRole("heading", { name: "Library" })).toBeVisible();
    expect(page.url().startsWith(`${baseUrl}library`)).toBe(true);

    await navigation.getByRole("link", { name: "Inspect" }).click();
    await expect(page.getByRole("radio", { name: "CBOR hex" })).toBeVisible();
    expect(page.url().startsWith(`${baseUrl}inspect`)).toBe(true);
    expect(new URL(page.url()).pathname).not.toBe("/inspect");
  });
});

test("MD3 inspector surfaces expose tokenized panels and controls", async ({
  page,
}) => {
  await page.addInitScript(() => {
    localStorage.setItem("cardano-ledger-inspector-theme", "light");
  });
  await decodeFixtureAt(page, "/inspect");

  const providerPanel = page.locator(".provider-panel");
  const inputPanel = page.locator(".input-panel");
  const resultPanel = page.locator(".result-panel");
  const identityPanel = page.locator(".identity-panel").first();
  const validationPanel = page.locator(".validation-panel");
  const rdfPanel = page.locator(".rdf-panel");
  const lensPanel = page.locator(".sparql-lens-panel").first();

  await expect(providerPanel).toHaveAttribute("data-md3-surface", "provider");
  await expect(inputPanel).toHaveAttribute("data-md3-surface", "input");
  await expect(resultPanel).toHaveAttribute("data-md3-surface", "result");
  await expect(identityPanel).toHaveAttribute("data-md3-surface", "decoded");
  await expect(validationPanel).toHaveAttribute("data-md3-surface", "decoded");
  await expect(rdfPanel).toHaveAttribute("data-md3-surface", "decoded");
  await expect(lensPanel).toHaveAttribute("data-md3-surface", "decoded");

  await expect(page.getByRole("button", { name: "Decode" })).toHaveAttribute(
    "data-md3-control",
    "primary",
  );
  await expect(page.getByRole("button", { name: "Copy JSON" })).toHaveAttribute(
    "data-md3-control",
    "secondary",
  );
  await expect(page.getByRole("button", { name: "Copy current" })).toHaveAttribute(
    "data-md3-control",
    "inline",
  );

  await expectColorToken(
    page,
    providerPanel,
    "backgroundColor",
    "--md-sys-color-surface-container-low",
  );
  await expectColorToken(
    page,
    providerPanel,
    "borderColor",
    "--md-sys-color-outline-variant",
  );

  const lightBackground = await providerPanel.evaluate(
    (element) => getComputedStyle(element).backgroundColor,
  );
  await page.getByRole("button", { name: "Toggle theme" }).click();
  await expect
    .poll(() => page.evaluate(() => document.documentElement.dataset.theme))
    .toBe("dark");
  await expectColorToken(
    page,
    providerPanel,
    "backgroundColor",
    "--md-sys-color-surface-container-low",
  );
  await expect(providerPanel).not.toHaveCSS("background-color", lightBackground);
});

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

  const lensPanel = page.locator(".sparql-lens-panel");
  await expect(
    lensPanel.getByRole("heading", {
      name: "SPARQL lens: transaction outputs",
    }),
  ).toBeVisible();
  await expect(lensPanel.locator(".sparql-lens-row").first()).toBeVisible();
  await expect(lensPanel.getByText("5", { exact: true })).toBeVisible();
  await expect(lensPanel.getByText(/urn:cardano:tx:/)).toBeVisible();
});

test("selects Amaru overlay book parts into deterministic Turtle", async ({
  page,
}) => {
  const journalJson = await readFile(amaruJournalFixturePath, "utf8");
  await decodeFixture(page);

  const overlayPanel = page.locator(".overlay-book-panel");
  await expect(
    overlayPanel.getByRole("heading", { name: "Overlay books" }),
  ).toBeVisible();

  await overlayPanel
    .getByLabel("Overlay Turtle or Amaru journal JSON")
    .fill(journalJson);
  await overlayPanel.getByRole("button", { name: "Import overlay book" }).click();

  const selectedTurtle = overlayPanel.getByLabel("Selected overlay Turtle");
  const coreDevelopment = overlayPanel.getByLabel("Core development");
  const resolvedLabelsPanel = page.locator(".resolved-labels-panel");
  await coreDevelopment.check();
  await expect(selectedTurtle).toHaveValue(/Amaru Core Development treasury/);
  await expect(selectedTurtle).toHaveValue(/@prefix cardano:/);
  await expect(
    resolvedLabelsPanel.getByRole("heading", {
      name: "SPARQL lens: resolved labels",
    }),
  ).toBeVisible();
  await expect(
    resolvedLabelsPanel.getByText("Amaru Core Development treasury", {
      exact: true,
    }),
  ).toBeVisible();
  await expect(resolvedLabelsPanel.getByText("Treasury", { exact: true })).toBeVisible();

  await coreDevelopment.uncheck();
  await expect(selectedTurtle).not.toHaveValue(/Amaru Core Development treasury/);
  await expect(
    resolvedLabelsPanel.getByText("Amaru Core Development treasury", {
      exact: true,
    }),
  ).toHaveCount(0);
  await expect(
    resolvedLabelsPanel.getByText("No resolved labels.", { exact: true }),
  ).toBeVisible();
});

test("imports a SundaeSwap blueprint book and applies typed RDF fields", async ({
  page,
}) => {
  const blueprintJson = await readFile(sundaeBlueprintFixturePath, "utf8");
  await decodeFixture(page, signingIntentFixturePath);

  const rdfPanel = page.locator(".rdf-panel");
  const turtle = rdfPanel.locator(".rdf-turtle");
  const typedFieldsPanel = page.locator(".typed-fields-panel");
  await expect(turtle).not.toContainText(":OrderDatum_max_protocol_fee 1280000");
  await expect(
    typedFieldsPanel.getByText("OrderDatum_max_protocol_fee", { exact: true }),
  ).toHaveCount(0);
  await expect(typedFieldsPanel.getByText("1280000", { exact: true })).toHaveCount(0);

  const overlayPanel = page.locator(".overlay-book-panel");
  await overlayPanel.getByLabel(/Overlay Turtle.*JSON/).fill(blueprintJson);
  await overlayPanel.getByRole("button", { name: /Import .*book/ }).click();

  const sundaeBlueprint = overlayPanel.getByLabel("SundaeSwap V3 blueprint");
  await expect(sundaeBlueprint).toBeVisible();
  await sundaeBlueprint.check();
  await overlayPanel.getByRole("button", { name: "Apply selected books" }).click();

  await expect(turtle).toContainText(":OrderDatum_max_protocol_fee 1280000");
  await expect(
    typedFieldsPanel.getByRole("heading", {
      name: "SPARQL lens: typed contract fields",
    }),
  ).toBeVisible();

  const typedRow = typedFieldsPanel
    .locator(".sparql-lens-row")
    .filter({ hasText: "OrderDatum_max_protocol_fee" })
    .filter({ hasText: "1280000" });
  await expect(typedRow.first()).toBeVisible();

  const turtleText = await turtle.innerText();
  const queryResult = await page.evaluate((graph) => {
    const query = `
      PREFIX : <https://lambdasistemi.github.io/cardano-rdf/fixtures/tx-rdf#>
      SELECT ?subject ?value WHERE {
        ?subject :OrderDatum_max_protocol_fee ?value .
      }
    `;

    return globalThis.rdfShapes.query(graph, query);
  }, turtleText);
  expect(queryResult.kind).toBe("solutions");
  expect(
    queryResult.json.results.bindings.map((binding) => binding.value.value),
  ).toContain("1280000");

  await sundaeBlueprint.uncheck();
  await overlayPanel.getByRole("button", { name: "Apply selected books" }).click();

  await expect(turtle).not.toContainText(":OrderDatum_max_protocol_fee 1280000");
  await expect(typedRow).toHaveCount(0);
});

test("exposes the vendored RDF query engine", async ({ page }) => {
  await page.goto("/");

  const result = await page.evaluate(() => {
    const graph = `
      @prefix ex: <https://example.test/> .
      ex:tx ex:label "demo transaction" .
    `;
    const query = `
      PREFIX ex: <https://example.test/>
      SELECT ?label WHERE { ex:tx ex:label ?label }
    `;

    return globalThis.rdfShapes.query(graph, query);
  });

  expect(result.kind).toBe("solutions");
  expect(result.json.results.bindings[0].label.value).toBe("demo transaction");
});

test("imports bundled SHACL shapes as selectable parts", async ({ page }) => {
  await decodeFixture(page);

  const validateType = await page.evaluate(() => typeof globalThis.rdfShapes.validate);
  expect(validateType).toBe("function");

  const overlayPanel = page.locator(".overlay-book-panel");
  await overlayPanel
    .getByRole("button", { name: "Load Cardano RDF SHACL shapes" })
    .click();

  const shapesPart = overlayPanel.getByLabel("Cardano transaction SHACL shapes");
  await expect(shapesPart).toBeVisible();
  await shapesPart.check();
  await expect(shapesPart).toBeChecked();
  await expect(overlayPanel.getByLabel("Selected overlay Turtle")).toHaveValue("");
});

test("renders conforming SHACL conformance for bundled Cardano RDF shapes", async ({
  page,
}) => {
  await decodeFixture(page);

  const overlayPanel = page.locator(".overlay-book-panel");
  await overlayPanel
    .getByRole("button", { name: "Load Cardano RDF SHACL shapes" })
    .click();
  await overlayPanel.getByLabel("Cardano transaction SHACL shapes").check();
  await overlayPanel.getByRole("button", { name: "Apply selected books" }).click();

  const conformancePanel = page.locator(".shacl-conformance-panel");
  await expect(
    conformancePanel.getByRole("heading", { name: "RDF SHACL conformance" }),
  ).toBeVisible();
  await expect(conformancePanel.getByText("Cardano transaction SHACL shapes")).toBeVisible();
  await expect(
    conformancePanel
      .locator(".metric-card", { hasText: "Author gate" })
      .getByText("pass", { exact: true }),
  ).toBeVisible();
  await expect(
    conformancePanel
      .locator(".metric-card", { hasText: "Auditor classifier" })
      .getByText("canonical-pipeline match", { exact: true }),
  ).toBeVisible();
  await expect(
    conformancePanel.getByText("No SHACL violations.", { exact: true }),
  ).toBeVisible();
});

test("renders non-conforming SHACL violations for pasted shapes", async ({
  page,
}) => {
  await decodeFixture(page);

  const overlayPanel = page.locator(".overlay-book-panel");
  await overlayPanel.getByLabel(/Overlay Turtle.*JSON/).fill(violatingShaclShapes);
  await overlayPanel.getByRole("button", { name: /Import .*book/ }).click();
  await overlayPanel.getByLabel("Pasted SHACL shapes").check();
  await overlayPanel.getByRole("button", { name: "Apply selected books" }).click();

  const conformancePanel = page.locator(".shacl-conformance-panel");
  await expect(
    conformancePanel.getByRole("heading", { name: "RDF SHACL conformance" }),
  ).toBeVisible();
  await expect(
    conformancePanel
      .locator(".metric-card", { hasText: "Author gate" })
      .getByText("fail", { exact: true }),
  ).toBeVisible();
  await expect(
    conformancePanel
      .locator(".metric-card", { hasText: "Auditor classifier" })
      .getByText("foreign/off-spec", { exact: true }),
  ).toBeVisible();

  const violationRow = conformancePanel.locator(".shacl-violation-row").filter({
    hasText: "Transactions must include sentinel off-spec marker.",
  });
  await expect(violationRow).toBeVisible();
  await expect(violationRow.getByText("Focus node", { exact: true })).toBeVisible();
  await expect(violationRow.getByText("Path", { exact: true })).toBeVisible();
  await expect(violationRow.getByText("Source shape", { exact: true })).toBeVisible();
  await expect(violationRow).toContainText("requiresSentinel");
  await expect(violationRow).toContainText("RequiresSentinelShape");
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

test("passes producer transaction CBOR into RDF resolved value flow", async ({
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

  const turtle = page.locator(".rdf-panel .rdf-turtle");
  await expect(turtle).toContainText("cardano:resolvedTo");
  await expect(turtle).toContainText("resolvedInput");
  expect(producerCborRequests).toBeGreaterThan(0);
  expect(latestBlockRequests).toBe(1);
  expect(protocolParameterRequests).toBe(1);
  expect(utxoRequests).toBe(0);
});

test("surfaces hard provider context resolution failures", async ({
  page,
}) => {
  const txCbor = (await readFile(fixturePath, "utf8")).trim();

  await installClipboardMock(page);
  await page.addInitScript(() => {
    Object.defineProperty(globalThis, "runInspector", {
      configurable: true,
      set(originalRunInspector) {
        Object.defineProperty(globalThis, "runInspector", {
          configurable: true,
          writable: true,
          value: async (stdinText) => {
            const request = JSON.parse(stdinText);
            const result = await originalRunInspector(stdinText);
            if (request && request.op === "tx.inspect") {
              return { ...result, exitOk: true, stdout: "{not-json" };
            }
            return result;
          },
        });
      },
    });
  });

  await page.goto("/");
  await page
    .getByPlaceholder("mainnet... / preprod... / preview...")
    .fill("mainnet-test-project");
  await page.getByRole("radio", { name: "CBOR hex" }).check();
  await page.getByPlaceholder("Conway tx CBOR hex...").fill(txCbor);
  await page.getByRole("button", { name: "Decode" }).click();

  const providerResolution = page
    .locator(".validation-panel .witness-section")
    .filter({ hasText: "Provider resolution" });
  await expect(providerResolution.getByText("provider error").first()).toBeVisible();
  await expect(providerResolution).toContainText(/provider context|Unexpected token|JSON/);
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
