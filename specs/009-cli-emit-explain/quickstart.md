# Quickstart: tx-deep-diagnosis Stdout Explain Format

## Build the CLI

```bash
nix build .#packages.x86_64-linux.tx-deep-diagnosis -o result-cli
```

## Print the explanation to stdout

```bash
./result-cli/bin/tx-deep-diagnosis \
  --cbor specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex \
  --network mainnet \
  --format explain
```

Expected result:

- stdout is a markdown explanation
- no extra files are written

## Also write the explanation bundle

```bash
./result-cli/bin/tx-deep-diagnosis \
  --cbor specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex \
  --network mainnet \
  --format explain \
  --emit-explain out
```

Expected result:

- stdout is still the markdown explanation
- `out/summary.md` exists
- `out/explain.md` exists
- `out/parties.mmd` exists
- `out/value-flow.tsv` exists
- `out/topology.mmd` exists
- `out/failures.mmd` exists only when failures are present

## Verify the shared renderer path

```bash
nix build .#checks.x86_64-linux.tx-explain-render-smoke
nix build .#checks.x86_64-linux.tx-deep-diagnosis-emit-explain-smoke
```
