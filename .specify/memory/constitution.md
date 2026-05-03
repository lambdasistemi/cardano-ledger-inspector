# Cardano Ledger Inspector Constitution

## Core Principles

### I. Ledger Code Is Authoritative
This repository exposes Cardano ledger semantics through a single Haskell
library (`libs/cardano-ledger-inspector`) compiled to multiple targets:
wasm32-wasi (loaded by the browser workbench), wasm32-wasi as an Extism
plugin (for cross-implementation conformance), and natively (linked into
host applications such as `apps/tx-deep-diagnosis`). Transaction decoding,
inspection, validation, evaluation, and any future operations MUST go
through the upstream Cardano ledger packages (`cardano-ledger-conway`,
`cardano-ledger-api`, `plutus-ledger-api`, etc.) wherever they exist.
Reimplementing ledger CBOR decoding, era rules, or `applyTx` semantics in
JavaScript, PureScript, Rust, or ad hoc JSON logic — in any consumer — is
out of scope unless it is explicitly documented as a temporary
compatibility shim.

### II. Transaction Documents Own State
Applications built here model user-visible work as explicit transaction
documents. The canonical transaction state is CBOR bytes owned by the
application/workspace. The inspector library MAY cache decoded values or
handles for performance, but cached state MUST NOT become authoritative
and MUST NOT make operation results depend on unobserved prior calls.

### III. JSON Control Plane, CBOR Data Plane
Ledger operation requests and responses use JSON for operation names, paths,
diagnostics, summaries, and simple arguments. CBOR remains the canonical
format for transactions and fidelity-sensitive ledger values. Structural
JSON is a view over ledger data, not a round-trippable ledger serialization.
The same JSON envelope works regardless of the consumer (browser via WASI,
Extism plugin host, native CLI), so a tx that decodes in one consumer
decodes byte-identically in the others.

### IV. Explicit Context Only
Every ledger operation receives the current transaction CBOR, explicit
operation arguments, and any external ledger context (producer txs, protocol
parameters, slot, epoch, network) required for reproducibility. Provider or
chain state MAY enter an operation only through an explicit request context
or an explicitly named provider fetch.

### V. The Library Is the Canonical Artifact
The repository's primary deliverable is the `cardano-ledger-inspector`
Haskell library. The per-target builds (WASI binary loaded in the browser,
Extism plugin, native executables, Nix derivations) are packaging of the
library, not implementations of the ledger semantics. A consumer is free
to add a new target — another wasm runtime, a direct library link, a
different host language via Extism — provided it consumes the inspector
library's typed entry points (`runLedgerOperationInput` and friends)
rather than reimplementing them.

## Quality Gates

- The wasm32-wasi build is reproducible through Nix (`.#wasm-tx-inspector`).
- The native build is reproducible through Nix via haskell.nix + CHaP
  (`.#tx-deep-diagnosis`).
- The Extism plugin build is reproducible through Nix (`.#wasm-extism-spike`)
  and matches the WASI reactor byte-for-byte on the same input
  (`.#tx-extism-spike-smoke`).
- Haskell sources under `libs/`, `apps/`, and `nix/wasm/` are Fourmolu-formatted
  (`.#format-check`).
- PureScript browser sources compile and the inspector workbench Playwright
  suite is green (`.#test-playwright`).
- Ledger operation contracts are documented before UI, host, or provider
  behavior depends on them.
- The OpenAPI source-of-truth in `nix/ledger-functional-openapi.nix` regenerates
  byte-identical to the committed `specs/001-ledger-functional-layer/openapi/...`
  JSON (`.#ledger-functional-openapi-check`).
- Every per-concern check is its own job in CI (`.github/workflows/ci.yml`)
  with its own GitHub identity, and `main` is branch-protected requiring
  every per-concern job to pass before merge
  (`scripts/setup-branch-protection.sh`).

## Development Workflow

- Nix-first: all local and CI commands run through `nix build` or `nix run`.
  CI does not use `nix develop -c <recipe>`; per-concern jobs invoke
  `nix run .#<app>` over checks wrapped as apps via
  `pkgs.writeShellApplication` + `pkgs.lib.getExe`.
- The build-gate populator `nix build`s every package + check (one cachix
  push per run); per-concern downstream jobs `nix run` cache hits with
  stdout visible.
- Pull requests are required after the initial bootstrap commit. Every PR
  must pass every required CI check before merging.
- Keep commits focused: infrastructure, library changes, per-target builds,
  host applications, browser UI, and documentation changes should be
  separable.
- Public artifacts and previews must be linked with HTTP URLs in handover
  messages and PR descriptions.

**Version**: 2.0.0 | **Ratified**: 2026-04-25 | **Last amended**: 2026-05-03
