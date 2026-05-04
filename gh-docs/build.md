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
and identity labels from a protocol registry. The default registry —
SundaeSwap V3 + treasury blueprints + the Amaru deployment journal — is
**bundled into the binary at build time** via cabal `data-files` and
loaded automatically (`Paths_tx_deep_diagnosis.getDataDir`), so
`nix run` works from anywhere with no checkout required.

### Inputs

```bash
result-cli/bin/tx-deep-diagnosis --help
```

```text
Usage: tx-deep-diagnosis --cbor FILE [--registry DIR] [--no-bundled-registry]
                         [--format FORMAT] [--emit-explain DIR] [--network NETWORK]
                         [--blockfrost-id PROJECT_ID]

Available options:
  --cbor FILE              Path to a file containing the Conway tx CBOR hex
  --registry DIR           Extra protocol registry directory to layer on top of
                           the bundled one. Repeat to add several. Validator +
                           instance entries from extra roots concat onto the
                           bundled list; the Amaru journal is last-wins.
  --no-bundled-registry    Skip the registry vendored into this binary at build
                           time. Only the directories passed via --registry are
                           consulted. Rare; meant for testing a clean replacement.
  --format FORMAT          stdout format: json | explain
  --emit-explain DIR       Also write summary.md, explain.md, and diagram artifacts
                           to DIR.
  --network NETWORK        mainnet | preprod | preview
  --blockfrost-id PID      Blockfrost project_id (or BLOCKFROST_PROJECT_ID env var)
```

### One-shot explain markdown on stdout

```bash
export BLOCKFROST_PROJECT_ID=mainnet…
result-cli/bin/tx-deep-diagnosis \
    --cbor specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex \
    --network mainnet \
    --format explain
```

The standard route is now explicit:

- `--format json` or no `--format`: typed JSON diagnosis envelope on stdout
- `--format explain`: single-file markdown explanation on stdout

If you also want the directory-shaped artifact bundle on disk, add
`--emit-explain out/`:

```bash
export BLOCKFROST_PROJECT_ID=mainnet…
result-cli/bin/tx-deep-diagnosis \
    --cbor specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex \
    --network mainnet \
    --format explain \
    --emit-explain out
```

That optional side output writes:

- `summary.md`
- `explain.md`
- `parties.mmd`
- `value-flow.tsv`
- `topology.mmd`
- `failures.mmd` when validation failures are present

Inside the JSON envelope, the two important sub-documents are:

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

If `--emit-explain` is omitted, stdout is unaffected; only the extra files are
skipped.

### Adding your own protocol identifications

The bundled registry covers SundaeSwap V3 and Amaru's deployment scopes.
For your own protocol, drop a directory shaped like
`docs/inspector/protocols/` (a `registry.json` plus optional vendored
blueprints) and pass it with `--registry`:

```bash
tx-deep-diagnosis \
  --cbor my-tx.hex \
  --registry ./my-protocol-registry \
  --registry ./my-other-protocol-registry
```

The bundled registry is always loaded as the base layer; the
`--registry` directories add to it. Validator and instance entries
from extra roots concat onto the bundled list (later roots' entries
shadow earlier ones at lookup time); the Amaru-style deployment
journal is last-wins. To skip the bundle entirely (e.g. when testing
a fully replaced registry), add `--no-bundled-registry`.

### One-liner from GitHub (no checkout)

```bash
BLOCKFROST_PROJECT_ID=<key> \
  nix run github:lambdasistemi/cardano-ledger-inspector#tx-deep-diagnosis -- \
    --cbor my-tx.hex \
    --format explain \
    --emit-explain out
```

The bundled registry travels inside the flake output, so script-hash
labels (e.g. `Amaru network_compliance treasury`) are present even
without a local checkout.

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
