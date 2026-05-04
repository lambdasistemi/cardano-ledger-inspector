# Quickstart: Formalize tx.intent Output Rows and Asset Detail

## Verify the tx.intent contract

```bash
nix build .#checks.x86_64-linux.tx-intent-smoke
nix build .#checks.x86_64-linux.ledger-functional-openapi-check
```

## Verify the renderer

```bash
nix build .#checks.x86_64-linux.tx-explain-render-smoke
```

## Verify formatting

```bash
just format-check
```
