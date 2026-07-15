# Feature Specification: Slim the inspector to an engine repo

**Feature Branch**: `refactor/150-slim-to-engine-repo`
**Created**: 2026-07-15
**Status**: Ready for implementation
**Input**: GitHub issue #150, “Slim the inspector to an engine repo”. Child
of epic `lambdasistemi/cardano-swiss-knife#20` after csk#18 established the
replacement workbench.

## User Scenarios & Testing

### User Story 1 — Follow the former inspector URL to the product workbench (Priority: P1)

As an engine consumer who visits the inspector repository or Pages site, I
find engine documentation and am sent from the former `/inspector/` route to
the unified cardano-swiss-knife workbench.

**Why this priority**: The source UI may be deleted only after the replacement
surface and redirect are proven. The live csk Pages root was independently
verified on 2026-07-15 and serves the Cardano transaction inspector at
`https://lambdasistemi.github.io/cardano-swiss-knife/`.

**Independent Test**: Build the Pages artifact, inspect
`_site/inspector/index.html`, and verify its redirect and fallback link both
name the exact live csk workbench URL.

**Acceptance Scenarios**:

1. **Given** the repository Pages build, **when** a visitor opens
   `/cardano-ledger-inspector/inspector/`, **then** the page redirects to
   `https://lambdasistemi.github.io/cardano-swiss-knife/` and exposes a
   clickable fallback link to the same URL.
2. **Given** the live redirect target, **when** it is requested, **then** it
   returns HTTP 200 and identifies itself as the Cardano transaction inspector.
3. **Given** the Pages workflow, **when** it builds the site, **then** it
   publishes MkDocs, Swagger/OpenAPI, and the redirect without building or
   copying `tx-inspector-ui`.

### User Story 2 — Consume an engine-only repository (Priority: P1)

As a downstream consumer, I see and build the ledger engine surfaces—WASI,
Extism conformance, OpenAPI, native diagnosis CLI, and protocol registry—without
carrying the former browser implementation or its build/test dependencies.

**Independent Test**: The engine gate builds the named packages and checks,
runs the operation smokes and Extism conformance, builds the Pages artifact,
and finds no UI package, Playwright app/job, preview workflow, or PureScript UI
toolchain in the active flake/CI surface.

**Acceptance Scenarios**:

1. **Given** the slimmed repository, **when** its tracked files are inspected,
   **then** the PureScript workbench, Playwright suites, UI-only RDF editor
   package, UI generator, and `tools/ux-judge` are absent while
   `docs/inspector/protocols/` remains intact.
2. **Given** the flake, **when** its packages, checks, apps, and dev shell are
   evaluated, **then** `tx-inspector-ui`, `test-playwright`, and UI-only inputs
   and tools are absent; the default package is an engine artifact.
3. **Given** CI, **when** the build gate runs, **then** it publishes only the
   WASI and OpenAPI per-run artifacts and runs engine checks without a
   Playwright job or UI preview workflow.
4. **Given** the repository and Pages documentation, **when** a reader opens
   the README, overview, architecture, installation, build, or agent guide,
   **then** the repo is described as the engine used by csk rather than as the
   home of a browser product.

### User Story 3 — Preserve public engine contracts and release assets (Priority: P1)

As an existing consumer, I keep using the named engine outputs and release
asset names without a ledger operation, envelope, CLI, registry, or release
workflow change.

**Independent Test**: Compare the pre-change and post-change Nix store paths
for `packages.x86_64-linux.wasm-tx-inspector` and
`packages.x86_64-linux.protocol-registry`; run the registry drift check; verify
the release-assets workflow is byte-identical to `origin/main`.

**Acceptance Scenarios**:

1. **Given** cardano-swiss-knife consumes the inspector flake, **when** this
   change lands, **then** named outputs `wasm-tx-inspector`,
   `protocol-registry`, `protocol-registry-drift-check`, Extism artifacts, and
   OpenAPI outputs keep their names and behavior.
2. **Given** the bundled protocol registry, **when** the drift check runs,
   **then** it remains byte-identical to what `tx-deep-diagnosis` bundles.
3. **Given** a tagged release, **when** `release-assets.yml` runs, **then** it
   still publishes `cardano-ledger-reference-<tag>.wasm`,
   `wasm-tx-inspector-<tag>.wasm`, the OpenAPI tarball, and checksums exactly as
   before.
4. **Given** the operation envelope, Haskell engine, and native CLI, **when**
   their tests run, **then** no contract or behavior change is observed.

## Critical Traps and Scope Guards

1. **The protocol registry stays.** `docs/inspector/protocols/` is the source
   for both the CLI cabal `data-dir` and `packages.protocol-registry`; delete
   only its UI siblings. The subtree must remain byte-identical so the registry
   output store path and drift gate remain unchanged.
2. **The downstream flake surface stays.** csk directly consumes
   `packages.<system>.wasm-tx-inspector` and
   `packages.<system>.protocol-registry`. Those outputs, the drift check,
   Extism artifacts, and OpenAPI outputs must not change. Only UI-specific
   outputs and dependencies are removed; `packages.default` moves from the
   removed UI alias to `wasm-tx-inspector`.
3. **Release assets stay.** `.github/workflows/release-assets.yml` is forbidden
   implementation scope and must remain byte-identical.
4. **Deletion follows redirect proof.** The UI deletion slice cannot begin
   until the preceding slice has built the Pages site, proven the exact
   redirect target, and passed the existing gate.

## Requirements

### Functional Requirements

- **FR-001**: The Pages artifact MUST publish documentation and the OpenAPI
  bundle and MUST publish `/inspector/index.html` as a redirect to the exact
  live csk workbench URL.
- **FR-002**: The redirect MUST provide automatic navigation and an accessible
  fallback link, both targeting `https://lambdasistemi.github.io/cardano-swiss-knife/`.
- **FR-003**: UI source, Playwright tests/config, UI-only packages/builders,
  `tools/ux-judge`, and UI-only preview/CI surfaces MUST be removed.
- **FR-004**: `docs/inspector/protocols/` MUST remain at its current path and
  byte content.
- **FR-005**: The named downstream engine flake outputs MUST remain available;
  `wasm-tx-inspector` and `protocol-registry` MUST retain their pre-change Nix
  store paths.
- **FR-006**: Existing ledger-operation smokes, Extism byte-conformance,
  OpenAPI checks, formatting/lint checks, native diagnosis checks, protocol
  registry drift, and strict MkDocs build MUST pass without UI dependencies.
- **FR-007**: README, architecture, build, installation, overview, AGENTS, and
  the repository guide skill MUST describe the engine-only scope and point
  browser users to csk.
- **FR-008**: `.github/workflows/release-assets.yml`, ledger operation source,
  public schemas/contracts, CLI behavior, and registry content MUST not change.

## Non-goals

- No ledger operation, JSON envelope, schema, or native CLI behavior changes.
- No protocol registry relocation or content edit.
- No csk implementation change and no new user-facing feature.
- No release asset rename or release workflow cleanup.
- No migration of historical specs or changelog entries that accurately
  describe earlier UI work.

## Success Criteria

- **SC-001**: The built Pages artifact contains a validated `/inspector/`
  redirect to the live csk workbench plus the docs and OpenAPI bundle.
- **SC-002**: `rg` finds no active `tx-inspector-ui`, Playwright, PureScript UI,
  or preview-workflow coupling outside historical specs/changelog and the
  retained protocol registry.
- **SC-003**: The final engine gate, registry drift check, and strict docs build
  exit 0.
- **SC-004**: Before/after Nix store paths match for `wasm-tx-inspector` and
  `protocol-registry`, and the release-assets workflow checksum is unchanged.

