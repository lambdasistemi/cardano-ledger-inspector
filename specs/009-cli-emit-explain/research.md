# Research: tx-deep-diagnosis Stdout Explain Format

## Findings

1. The repository already has a single-file markdown renderer
   (`Render.Single.renderSingleMarkdown`) that can serve a stdout explain mode
   directly; the missing behavior is CLI routing, not rendering capability.
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
   gap is a runtime smoke that exercises `tx-deep-diagnosis --format explain`.
6. The user requirement is not “write files”; it is “if I ask for explain, the
   standard route should become markdown.” That makes stdout format selection
   the primary interface and file emission secondary.

## Decision

Keep the reusable `Render.Emit` module in the host library for the optional
directory-shaped artifact bundle, but make the CLI surface stdout-first:

- add `--format json|explain` to the runtime CLI
- route `json` to the existing envelope renderer
- route `explain` to `Render.Single.renderSingleMarkdown`
- parse the in-memory diagnosis document once when explain output or file
  emission is requested
- keep `--emit-explain DIR` as an additional side-output for users who want the
  artifact bundle too

Then make both:

- `tx-deep-diagnosis`
- `tx-deep-diagnosis-render-snapshot`

depend on that one module instead of each owning their own orchestration logic.
