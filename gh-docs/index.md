# Cardano Ledger WASI

Cardano Ledger WASI packages selected Cardano ledger operations as
`wasm32-wasi` executables and browser artifacts. The project exists so
tools can call the ledger code directly from WASI rather than reimplementing
ledger semantics in JavaScript or PureScript.

## Transaction Inspector

The transaction inspector is the first published workbench built on this
layer. It accepts transaction CBOR, runs the Haskell ledger WASI module in
the browser, and renders a browsable result.

[Open the inspector](inspector/){ .md-button .md-button--primary }

## Repository Scope

- WASI builds for selected ledger executables.
- A browser workbench that embeds the WASI artifact.
- A functional operation contract with JSON control messages and CBOR data.
- Nix and CI workflows for reproducible builds, GitHub Pages, and downloadable
  artifacts.

## Important Links

- Repository: [lambdasistemi/cardano-ledger-wasi](https://github.com/lambdasistemi/cardano-ledger-wasi)
- Inspector page: [GitHub Pages inspector](inspector/)
- API definition: [Functional API](api.md)
- Swagger UI: [OpenAPI reference](swagger.md)
- CI artifacts: [CI workflow runs](https://github.com/lambdasistemi/cardano-ledger-wasi/actions/workflows/ci.yml)
- Constitution: [`.specify/memory/constitution.md`](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/.specify/memory/constitution.md)
- Functional API contract: [`specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/contracts/ledger-functional-api.md)

## Design Commitments

The ledger code is authoritative. UI and host code may choose which operation
to run and how to present the result, but transaction interpretation belongs
to the Haskell ledger layer.

Transaction CBOR is the durable data plane. JSON is the control and response
language for operation requests because it is inspectable, easy to version,
and friendly to browser tooling.
