# Quickstart: tx.intent Withdrawal Detail

## Verify the contract shape

```bash
nix build .#checks.x86_64-linux.tx-intent-smoke -o result-intent-smoke
cat result-intent-smoke/response.json | jq '.result.intent.withdrawals'
```

## Verify the markdown render

```bash
nix build .#checks.x86_64-linux.tx-explain-render-smoke -o result-explain-smoke
cat result-explain-smoke/snapshot.log
```

## Verify the documented schema

```bash
nix build .#checks.x86_64-linux.ledger-functional-openapi-check -o result-openapi-check
```

## Formatting

```bash
just format-check
```
