# Quickstart: Explain Markdown Parity Phase 1

## 1. Compare the Current Golden Renderer Output

Run the dedicated snapshot smoke check:

```bash
nix build .#checks.x86_64-linux.tx-explain-render-smoke -o result-explain-smoke
cat result-explain-smoke/snapshot.log
```

This verifies every file under `apps/tx-deep-diagnosis/test/golden/<case>/expected/`
against the current pure renderers.

## 2. Regenerate Golden Files Intentionally

Build the snapshot executable and write fresh expected artifacts:

```bash
nix build .#packages.x86_64-linux.tx-deep-diagnosis-render-snapshot -o result-render-snapshot
./result-render-snapshot/bin/tx-deep-diagnosis-render-snapshot \
  --write apps/tx-deep-diagnosis/test/golden
```

Then inspect the markdown diff:

```bash
git diff -- apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md
git diff -- apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md
```

## 3. Re-run the Explain Smoke After Code Changes

```bash
nix build .#checks.x86_64-linux.tx-explain-render-smoke -o result-explain-smoke
cat result-explain-smoke/snapshot.log
```

Success means the renderer and the committed golden artifacts agree again.

## 4. Run Formatting

```bash
just format-check
```

## 5. Review the Reader-Facing Contract

Check the top of the generated `explain.md` for the scoped goals of this
feature:

- headline before verdict
- failures and balance above secondary sections
- fees/resources near the top
- self-declared claims visibly marked
- Mermaid diagrams collapsed in the single-file report
