# Build and Artifacts

## Build Locally

Build the WASI executable:

```bash
nix build .#packages.x86_64-linux.wasm-tx-inspector -o result-wasm
```

The executable is:

```text
result-wasm/wasm-tx-inspector.wasm
```

Build the browser bundle:

```bash
nix build .#packages.x86_64-linux.tx-inspector-ui -o result-site
```

The browser bundle is:

```text
result-site/index.html
result-site/index.js
```

Build the native CLI:

```bash
nix build .#packages.x86_64-linux.tx-deep-diagnosis -o result-cli
```

The CLI is:

```text
result-cli/bin/tx-deep-diagnosis
```

## Native CLI Tutorial

`tx-deep-diagnosis` links the same `cardano-ledger-inspector` library that
the browser loads as wasm. It produces a layered diagnosis of a Conway
transaction by combining `tx.intent` and `tx.validate` (both running real
`cardano-ledger-conway` code) with Blockfrost-resolved producer transactions
and identity labels from the protocol registry under
`docs/inspector/protocols/`.

### Inputs

```bash
result-cli/bin/tx-deep-diagnosis --help
```

```text
Usage: tx-deep-diagnosis --cbor FILE [--registry DIR] [--network NETWORK]
                         [--blockfrost-id PROJECT_ID]

  Layered Conway tx diagnosis using cardano-ledger-conway via the
  cardano-ledger-inspector library

Available options:
  --cbor FILE              Path to a file containing the Conway tx CBOR hex
  --registry DIR           Path to the protocol registry directory
                           (default: docs/inspector/protocols)
  --network NETWORK        mainnet | preprod | preview
  --blockfrost-id PID      Blockfrost project_id (or BLOCKFROST_PROJECT_ID env var)
```

### One-shot example on the SundaeSwap fixture

```bash
export BLOCKFROST_PROJECT_ID=mainnet…
result-cli/bin/tx-deep-diagnosis \
    --cbor specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex
```

The CLI prints two blocks of typed JSON:

1. **`tx.intent`** — decoded body, signer-perspective summary, claims drawn
   from auxiliary metadata (clearly labelled as self-declared), value buckets
   (signer-controlled / external-key / script / bootstrap), and a list of
   producer transactions whose CBOR the validator still needs.
2. **`tx.validate`** — the result of feeding the candidate plus the resolved
   producer transactions plus current protocol parameters into Conway
   `applyTx`. Predicate failures come back typed; the CLI does no rule
   checking of its own.

When the `--blockfrost-id` is omitted, the CLI runs `tx.intent` and a
context-less `tx.validate` (the validator says exactly which fields are
missing — `source_output`, `protocol_parameters`, `slot`, `epoch`,
`network` — instead of guessing).

### What the CLI adds beyond the wasm

Every `script_hash` it sees in inputs, outputs, withdrawals, or required
signers is cross-referenced against the registry:

- **Direct match** — the hash appears as an unparameterized `validators[]`
  entry in a vendored `plutus.json` (for example SundaeSwap V3
  `order.spend = fa6a58bb…3077`).
- **Parameterized instance** — the hash is a `treasury.treasury.spend`
  template applied with deployment-specific parameters; the registry's
  `instances[]` block + the Amaru deployment journal label it (for example
  the Network Compliance treasury `32201dc1…baa0d`).
- **Amaru role** — the hash is a `permissions_script` or `registry_script`
  for one of the five Amaru scopes; the journal labels it directly.

Required-signer keys are similarly cross-referenced against the journal's
scope owners, and reference-input outrefs are matched against deployment
outrefs. The result is a layered report in which a typed
`PredicateFailure { BadInputsUTxO }` is annotated with "this hash is the
Amaru Network Compliance treasury", not just the bare hex.

## Build From GitHub

```bash
nix build github:lambdasistemi/cardano-ledger-inspector#packages.x86_64-linux.wasm-tx-inspector
nix build github:lambdasistemi/cardano-ledger-inspector#packages.x86_64-linux.tx-inspector-ui
```

## Download CI Artifacts

Every `CI` workflow run uploads downloadable artifacts:

| Artifact | Contents |
| --- | --- |
| `wasm-tx-inspector` | `wasm-tx-inspector.wasm`, `SHA256SUMS` |
| `tx-inspector-ui` | `index.html`, `index.js`, `SHA256SUMS` |
| `ledger-functional-openapi` | OpenAPI JSON, referenced schemas, `SHA256SUMS` |

Download them from the artifact section of a CI run:

[CI workflow runs](https://github.com/lambdasistemi/cardano-ledger-inspector/actions/workflows/ci.yml)

## Published Documentation Site

GitHub Pages publishes this documentation site and mounts the transaction
inspector at:

<https://lambdasistemi.github.io/cardano-ledger-inspector/inspector/>
