# Quickstart: Datum Grouping and Explicit Amaru Treasury Schema

## Run the renderer smoke

```bash
nix build .#checks.x86_64-linux.tx-explain-render-smoke
```

## Refresh the committed golden markdown files

```bash
nix build .#packages.x86_64-linux.tx-deep-diagnosis-render-snapshot -o result-render-snapshot
./result-render-snapshot/bin/tx-deep-diagnosis-render-snapshot \
  --write apps/tx-deep-diagnosis/test/golden
```

Expected result:

- `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md`
  shows a separate treasury datum block
- `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md`
  shows the same split

## Verify formatting

```bash
just format-check
```
