# Research: tx-deep-diagnosis Runtime --emit-explain

## Findings

1. The closed explain-artifacts spec explicitly required `--emit-explain DIR`
   on the runtime CLI, but the current parser in
   `apps/tx-deep-diagnosis/app/Main.hs` does not include that option.
2. The repository already has all pure renderers needed for the runtime flag:
   `Render.Summary`, `Render.Single`, `Render.Parties`, `Render.Topology`,
   `Render.ValueFlow`, and `Render.Failures`.
3. The snapshot executable in `apps/tx-deep-diagnosis/snapshot/Main.hs` owns
   the artifact assembly order and the `EmittedFiles` bookkeeping today. That
   ownership is the reason runtime and test behavior drifted.
4. `TxDeepDiagnosisHost.Report.renderReport` currently only returns pretty JSON
   text. Runtime emission will be cleaner if the wrapped report `Value` is
   available before encoding to text.
5. `tx-explain-render-smoke` already covers renderer determinism. The missing
   gap is a runtime smoke that exercises `tx-deep-diagnosis --emit-explain`.

## Decision

Create a reusable `Render.Emit` module in the host library that:

- assembles the artifact list in deterministic write order
- handles optional `failures.mmd`
- computes the `summary.md` footer links from the actually rendered set
- writes/removes known output files for runtime use

Then make both:

- `tx-deep-diagnosis`
- `tx-deep-diagnosis-render-snapshot`

depend on that one module instead of each owning their own orchestration logic.
