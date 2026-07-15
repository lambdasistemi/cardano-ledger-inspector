# Cardano Ledger Inspector Engine

This repository packages Conway ledger operations as a `wasm32-wasi`
reactor, an Extism conformance plugin, an OpenAPI contract, a protocol
registry, and a native diagnosis CLI. Host tools can call authoritative
ledger code without reimplementing ledger semantics.

## Transaction Inspector

The browser transaction inspector moved to cardano-swiss-knife. It consumes
this repository's `wasm-tx-inspector` and `protocol-registry` flake outputs
and owns the browser UI and provider integrations.

[Open the cardano-swiss-knife workbench](https://lambdasistemi.github.io/cardano-swiss-knife/){ .md-button .md-button--primary }

## Repository Scope

- WASI builds for selected ledger executables.
- Extism and native host surfaces for conformance and diagnosis.
- A standalone protocol-registry output for downstream consumers.
- A functional operation contract with JSON control messages and CBOR data.
- Nix and CI workflows for reproducible engine builds, GitHub Pages,
  Swagger/OpenAPI, and downloadable artifacts.

## Important Links

- Repository: [lambdasistemi/cardano-ledger-inspector](https://github.com/lambdasistemi/cardano-ledger-inspector)
- Browser workbench: [cardano-swiss-knife](https://lambdasistemi.github.io/cardano-swiss-knife/)
- Former inspector route: [redirect to the workbench](inspector/)
- API definition: [Functional API](api.md)
- Swagger UI: [OpenAPI reference](swagger.md)
- CI artifacts: [CI workflow runs](https://github.com/lambdasistemi/cardano-ledger-inspector/actions/workflows/ci.yml)
- Constitution: [`.specify/memory/constitution.md`](https://github.com/lambdasistemi/cardano-ledger-inspector/blob/main/.specify/memory/constitution.md)
- Functional API contract: [`specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`](https://github.com/lambdasistemi/cardano-ledger-inspector/blob/main/specs/001-ledger-functional-layer/contracts/ledger-functional-api.md)

## Design Commitments

The ledger code is authoritative. Downstream hosts may choose which operation
to run and how to present the result, but transaction interpretation belongs
to the Haskell ledger layer.

Transaction CBOR is the durable data plane. JSON is the control and response
language for operation requests because it is inspectable, easy to version,
and friendly to host tooling.
