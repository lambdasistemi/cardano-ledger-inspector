# Cardano Ledger WASI Constitution

## Core Principles

### I. Ledger Code Is Authoritative
This repository exposes Cardano ledger semantics by compiling Haskell ledger
code to WASI. Transaction decoding, inspection, checking, patching, and future
balancing operations MUST go through the upstream ledger types and functions
wherever they exist. Reimplementing ledger CBOR or era rules in JavaScript,
PureScript, Rust, or ad hoc JSON logic is out of scope unless it is explicitly
documented as a temporary compatibility shim.

### II. Transaction Documents Own State
Applications built here model user-visible work as explicit transaction
documents. The canonical transaction state is CBOR bytes owned by the
application/workspace. Haskell/WASI code MAY cache decoded values or handles for
performance, but cached state MUST NOT become authoritative and MUST NOT make
operation results depend on unobserved prior calls.

### III. JSON Control Plane, CBOR Data Plane
Ledger operation requests and responses use JSON for operation names, paths,
diagnostics, summaries, and simple arguments. CBOR remains the canonical format
for transactions and fidelity-sensitive ledger values. Structural JSON is a view
over ledger data, not a round-trippable ledger serialization.

### IV. Explicit Context Only
Every ledger operation receives the current transaction CBOR, explicit
operation arguments, and any external ledger context required for
reproducibility. Provider or chain state MAY enter an operation only through an
explicit request context or an explicitly named provider fetch.

### V. WASI Artifacts Are First-Class
The repository's primary deliverables are WASI artifacts, the Nix builder that
produces them, and small browser/CLI references that prove the artifacts work.
The browser workbench exists to exercise the WASI ledger layer and demonstrate
the operation API. It is not allowed to become the authority for ledger
semantics.

## Quality Gates

- WASI packages build reproducibly through Nix.
- Haskell sources are Fourmolu-formatted.
- PureScript browser sources compile.
- Ledger operation contracts are documented before UI or provider behavior
  depends on them.
- Browser previews are verified with Playwright after UI changes.

## Development Workflow

- Nix-first: all local and CI commands run through `nix` or `just` recipes.
- Pull requests are required after the initial bootstrap commit.
- Keep commits focused: infrastructure, Haskell ledger operations, browser UI,
  and documentation changes should be separable.
- Public artifacts and previews must be linked with HTTP URLs in handover
  messages and PR descriptions.

**Version**: 1.0.0 | **Ratified**: 2026-04-25
