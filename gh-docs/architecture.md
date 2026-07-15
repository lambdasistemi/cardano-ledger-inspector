# Architecture

The project packages Cardano ledger operations as reproducible Nix outputs.
The WASI module, Extism spike, OpenAPI bundle, protocol registry, native CLI,
and smoke checks are separate artifacts, but they share one ledger operation
implementation. The cardano-swiss-knife browser workbench is an external
consumer of the engine outputs.

```mermaid
flowchart TB
  Tx[Transaction CBOR]
  Context[Explicit context]
  Envelope[Operation envelope]
  Inspector["libs/cardano-ledger-inspector<br/>(Conway inspector library)"]
  WASI[wasm-tx-inspector.wasm]
  Extism[wasm-extism-spike.wasm]
  Native["apps/tx-deep-diagnosis<br/>(native binary linking the lib)"]
  CSK["cardano-swiss-knife<br/>(external browser consumer)"]
  ExtHost[apps/extism-spike-host]
  Ledger[Cardano ledger packages]
  JSON[JSON result]

  Tx --> Envelope
  Context --> Envelope
  CSK --> Envelope
  ExtHost --> Envelope
  Native --> Envelope
  Envelope --> WASI
  Envelope --> Extism
  Envelope --> Inspector
  WASI --> Inspector
  Extism --> Inspector
  Inspector --> Ledger
  Ledger --> Inspector
  Inspector --> JSON
  JSON --> CSK
  JSON --> ExtHost
  JSON --> Native
```

The same `cardano-ledger-inspector` Haskell library is compiled three ways:
to wasm32-wasi, to wasm32-wasi as an Extism plugin, and natively (linked into
`apps/tx-deep-diagnosis`). Every consumer talks to the same dispatcher and
gets the same JSON contract.

## Layers

### Consumer Boundary

The cardano-swiss-knife repository owns the browser product, local UI state,
and provider adapters. It consumes the named `wasm-tx-inspector` and
`protocol-registry` flake outputs from this repository. The engine receives
transaction CBOR and explicit context through its versioned JSON envelope; it
does not depend on hidden browser state or provider calls.

### Inspector library

`libs/cardano-ledger-inspector/` is the canonical Haskell library. Modules
under `src/Conway/Inspector*` decode Conway transaction CBOR via the upstream
`cardano-ledger-conway` packages, run `applyTx`, evaluate Plutus scripts, and
return typed JSON results behind a single dispatcher entry
(`runLedgerOperationInput`). Three executables compile this library to
different targets, all from the same source.

### WASI Layer

The library's `app/Main.hs` is a 34-line WASI reactor that reads one JSON
envelope (or raw transaction hex) from stdin and writes one JSON response. Its wasm build, configured
by `libs/cardano-ledger-inspector/cabal-wasm.project`, produces
`wasm-tx-inspector.wasm`. WASI hosts provide the envelope on stdin and read
the JSON response on stdout.

### Extism Layer

`apps/wasm-extism-spike/` packages the same inspector library as an Extism PDK
plugin. The exported functions are operation entry points such as
`tx_identify`, `tx_validate`, and `tx_evaluate_scripts`; each one accepts the
same JSON envelope as the WASI reactor and delegates to the shared inspector
dispatcher.

`apps/extism-spike-host/` is a native Haskell host used for conformance checks.
It links the prebuilt `libextism` runtime from `nix/host/libextism.nix` because
the current nixpkgs `extism-cli` path is blocked by wazero tail-call support.

### Native CLI Layer

`apps/tx-deep-diagnosis/` is a native Haskell host that links the inspector
library directly (no wasm in the loop). It calls
`Conway.Inspector.runLedgerOperationInput` for `tx.intent` and `tx.validate`,
adds Blockfrost producer-tx resolution, and labels script hashes against
vendored CIP-57 blueprints + the Amaru deployment journal under
`docs/inspector/protocols/`. Built via `pkgs.haskell-nix.cabalProject'` with
CHaP and the same GHC 9.8.4 setup the cardano-mpfs-offchain project uses.

### Ledger Layer

`cardano-ledger-conway`, `cardano-ledger-api`, `plutus-ledger-api` and friends
provide all transaction-decoding and validation logic. Both the wasm and native
builds of the inspector library link the same versions (pinned via CHaP). This
keeps every consumer aligned with ledger behaviour instead of maintaining a
second transaction model.

## State Model

Host applications own state. A browser or CLI can manage many transactions,
select one, and pass its CBOR to a WASI operation. The WASI operation itself
receives explicit inputs and returns explicit outputs.

This keeps operations reproducible while still allowing richer host workflows,
such as transaction collections, comparison views, or future editing and
balancing tools.

## Flake Output Design

The flake is intentionally split into reusable library code, build artifacts,
checks, and a development shell. Outputs are exposed for `x86_64-linux` and
`aarch64-darwin`; CI currently exercises the Linux outputs.

```mermaid
flowchart TB
  Lib[lib.wasm]
  WasmTargets[WASM package targets]
  HostTargets[Native host targets]
  OpenAPI[OpenAPI artifacts]
  Registry[Protocol registry]
  Checks[Smoke and contract checks]
  DevShell[devShells.default]

  Lib --> WasmTargets
  Registry --> HostTargets
  WasmTargets --> Checks
  HostTargets --> Checks
  OpenAPI --> Checks
  DevShell --> Checks
```

### Library Outputs

| Output | Purpose |
| --- | --- |
| `lib.wasm.cabalWasmProjectFragment` | Reusable Cabal project stanza for Cardano ledger WASM builds. |
| `lib.wasm.mkCardanoLedgerWasm` | Helper that builds a Haskell package set with `wasm32-wasi-ghc`, CHaP, source-repository-package forks, optional WASI C libraries, and a locked dependency cache. |
| `lib.wasm.forks` | The fork metadata used by the WASM Cabal project fragment. |

These outputs are system-agnostic. Package and check outputs pass the
per-system `pkgs`, `ghc-wasm-meta`, CHaP source, and target source tree into
`mkCardanoLedgerWasm`.

### Package Outputs

| Output | Contents | Role |
| --- | --- | --- |
| `packages.<system>.wasm-smoke` | `wasm-smoke.wasm` | Minimal CBOR-only WASM build proving the GHC WASM toolchain and dependency-cache pattern. |
| `packages.<system>.wasm-ledger-smoke` | `wasm-ledger-smoke.wasm` | Full ledger closure smoke target, including WASM-built crypto C libraries. |
| `packages.<system>.wasm-tx-inspector` | `wasm-tx-inspector.wasm` | Main WASI functional layer module. It reads one JSON envelope from stdin and writes one JSON response. |
| `packages.<system>.wasm-extism-spike` | `wasm-extism-spike.wasm` | Extism PDK plugin exposing the same ledger operation contract through named exports. |
| `packages.<system>.extism-spike-host` | Native executable `extism-spike-host` | Wasmtime-backed host used to call the Extism plugin in checks. |
| `packages.<system>.tx-deep-diagnosis` | Native executable `tx-deep-diagnosis` | Native CLI that links the inspector library, resolves inputs via Blockfrost, and labels script hashes against vendored blueprints + the Amaru journal. Produces a layered diagnosis report. |
| `packages.<system>.tx-deep-diagnosis-render-snapshot` | Native executable `tx-deep-diagnosis-render-snapshot` | Golden-file snapshot harness for the explain-artifact renderers; `--write` regenerates the expected files under `apps/tx-deep-diagnosis/test/golden/`. |
| `packages.<system>.libextism` | Native `libextism` library and headers | Prebuilt Extism runtime used by the native host package. |
| `packages.<system>.protocol-registry` | Registry manifest, blueprints, pins, deployment journal, and registry documentation | Standalone registry consumed by cardano-swiss-knife and checked against the native CLI's bundled data. |
| `packages.<system>.ledger-functional-openapi-generated` | Generated `cardano-ledger-functional.openapi.json` | Deterministic OpenAPI JSON generated from the Nix source definition. |
| `packages.<system>.ledger-functional-openapi` | OpenAPI JSON plus referenced schema JSON files | Publishable API bundle for docs and CI artifacts. |
| `packages.<system>.ledger-functional-swagger` | Alias of `ledger-functional-openapi` | Compatibility output for consumers that still look for the Swagger name. |
| `packages.<system>.default` | Alias of `wasm-tx-inspector` | Default engine package for `nix build`. |

The WASM package targets use fixed-output dependency derivations. When Cabal
inputs, CHaP pins, source-repository-package forks, or package lists change,
the target's `dependenciesHash` is recomputed deliberately instead of allowing
implicit network access during the final build.

### Check Outputs

| Output | What it verifies |
| --- | --- |
| `checks.<system>.ledger-functional-openapi-check` | Regenerates OpenAPI JSON from `nix/ledger-functional-openapi.nix` and diffs it against the committed file under `specs/001-ledger-functional-layer/openapi/`. |
| `checks.<system>.ledger-functional-swagger-check` | Alias of the OpenAPI check for the Swagger compatibility name. |
| `checks.<system>.tx-identify-smoke` | Runs `tx.identify` through `wasm-tx-inspector.wasm` and asserts stable identity, size, fee, and witness-count fields. |
| `checks.<system>.tx-rdf-smoke` | Runs deterministic RDF projection checks, including resolved inputs and blueprint-aware datum decoding. |
| `checks.<system>.tx-witness-plan-smoke` | Runs `tx.witness.plan` without context and asserts witness, script, datum, redeemer, and warning shapes. |
| `checks.<system>.tx-witness-attach-smoke` | Runs `tx.witness.attach`, asserts inserted vs replaced behavior, preserves transaction identity, and checks rejected missing-witness diagnostics. |
| `checks.<system>.tx-intent-smoke` | Runs `tx.intent` against a complete producer-context fixture and verifies signer-perspective value accounting. |
| `checks.<system>.tx-input-context-smoke` | Derives synthetic producer transaction context from inspection output and verifies resolved input reporting. |
| `checks.<system>.tx-validate-smoke` | Covers missing context, unsupported provider-style UTxO JSON, complete valid context, deterministic validation output, and invalid supplied network context. |
| `checks.<system>.tx-evaluate-scripts-smoke` | Covers missing context, rejected provider-style UTxO JSON, complete script evaluation, deterministic output, budgeted units, and evaluated units. |
| `checks.<system>.tx-extism-spike-smoke` | Calls the Extism plugin through `extism-spike-host` and checks that Extism responses for shared envelopes match the WASI reactor byte-for-byte. |
| `checks.<system>.tx-explain-render-smoke` | Runs the render-snapshot harness in compare mode against the committed golden explain artifacts. |
| `checks.<system>.tx-deep-diagnosis-emit-explain-smoke` | Runs the native CLI with `--emit-explain` end-to-end and verifies the emitted artifact set. |
| `checks.<system>.cardano-ledger-wasm-pin-check` | Verifies the WASM source pins and fork metadata remain aligned. |
| `checks.<system>.protocol-registry-drift-check` | Verifies the CLI's bundled registry data is byte-identical to the standalone registry package for every consumed file. |

The smoke checks are intentionally fixture-driven. They do not fetch provider
state or hide network lookups inside the ledger layer; all transaction CBOR and
context evidence comes from committed fixtures or from synthetic values created
inside the check.

### Development Shell

`devShells.<system>.default` provides the tools used by local development and
CI recipes:

| Tool | Use |
| --- | --- |
| `just` | Task runner for the documented local workflow. |
| `wasmtime` | Runs WASI artifacts in smoke checks and manual tests. |
| `jq` | Builds request fixtures and asserts JSON response contracts. |
| `curl` | Manual API/provider probing when needed. |
| `nixfmt-rfc-style` | Nix formatting. |
| `fourmolu` | Haskell formatting. |
| `mkdocs`, `mkdocs-material`, `pymdown-extensions` | Documentation site build. |

## CI and Artifact Flow

The flake outputs define the CI surface:

1. Build the WASI module, Extism/native packages, protocol registry, and
   OpenAPI bundle from pinned inputs.
2. Regenerate and compare the OpenAPI output against the committed spec.
3. Run fixture-based WASI and Extism smoke checks.
4. Upload downloadable artifacts for the WASI and OpenAPI bundles.
5. Publish the MkDocs site and Swagger/OpenAPI assets; `/inspector/` is a
   static redirect to cardano-swiss-knife.

This keeps the repository docs, downloadable engine artifacts, downstream
registry package, and contract checks tied to the same Nix output graph.
