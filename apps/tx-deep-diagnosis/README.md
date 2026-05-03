# tx-deep-diagnosis

`tx-deep-diagnosis` renders a layered markdown explanation for one diagnosis
JSON envelope. The reader-first contract for the top of the report is:

1. Title and tx id
2. Headline action summary
3. Verdict
4. Validation failures
5. Balance
6. Fees & resources
7. Observations
8. Claims
9. Effects
10. Smart-contract calls
11. Withdrawals
12. Outputs
13. Datums
14. Warnings
15. Diagrams

`summary.md` uses that order directly. `explain.md` uses the same summary and
then embeds the Mermaid diagrams at the end inside collapsed `<details>` blocks.

## Snapshot verification

Compare the current renderers against the committed golden files:

```bash
nix build .#checks.x86_64-linux.tx-explain-render-smoke -o result-explain-smoke
cat result-explain-smoke/snapshot.log
```

Regenerate the expected markdown files intentionally:

```bash
nix build .#packages.x86_64-linux.tx-deep-diagnosis-render-snapshot -o result-render-snapshot
./result-render-snapshot/bin/tx-deep-diagnosis-render-snapshot \
  --write apps/tx-deep-diagnosis/test/golden
```
