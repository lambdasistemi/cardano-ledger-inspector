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

## Build From GitHub

```bash
nix build github:lambdasistemi/cardano-ledger-wasi#packages.x86_64-linux.wasm-tx-inspector
nix build github:lambdasistemi/cardano-ledger-wasi#packages.x86_64-linux.tx-inspector-ui
```

## Download CI Artifacts

Every `CI` workflow run uploads downloadable artifacts:

| Artifact | Contents |
| --- | --- |
| `wasm-tx-inspector` | `wasm-tx-inspector.wasm`, `SHA256SUMS` |
| `tx-inspector-ui` | `index.html`, `index.js`, `SHA256SUMS` |
| `ledger-functional-openapi` | OpenAPI JSON, referenced schemas, `SHA256SUMS` |

Download them from the artifact section of a CI run:

[CI workflow runs](https://github.com/lambdasistemi/cardano-ledger-wasi/actions/workflows/ci.yml)

## Published Documentation Site

GitHub Pages publishes this documentation site and mounts the transaction
inspector at:

<https://lambdasistemi.github.io/cardano-ledger-wasi/inspector/>
