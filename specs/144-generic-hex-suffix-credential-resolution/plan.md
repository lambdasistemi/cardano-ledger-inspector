# Implementation Plan: Generic hex-suffix credential resolution

**Branch**: `feat/144-generic-hex-suffix-resolution` | **Date**: 2026-07-12 | **Spec**: [spec.md](spec.md)

## Summary

Extend the fixed resolved-label SPARQL lens so a book-side generic credential
identity joins a credential-specific transaction identity on its hexadecimal
suffix. Preserve the existing rows, return the concrete transaction identity
as the match, and prove the result through the existing browser test harness.

## Technical Context

**Language/Version**: JavaScript FFI called from the existing PureScript
workbench.  
**Primary Dependencies**: The bundled `rdfShapes` SPARQL implementation and
the existing Playwright suite.  
**Testing**: Focused Playwright test in `docs/inspector/tests/tx-identify.spec.mjs`; `just ui-check`; packaged UI build.  
**Target Platform**: Browser workbench built through Nix.  
**Constraints**: Do not edit `docs/inspector/src/Main.purs`, any book Turtle,
or the tx-graph emitter. Keep the type-blind same-hash collision limitation
visible beside the query.

## Constitution Check

The repository has no additional feature constitution outside its existing
agent and formatting rules. The plan complies: the source change is isolated
to the RDF query FFI; the regression runs through the packaged UI; no hidden
context or external emitter/book mutation is introduced.

## Design

1. Keep the current direct-label resolution path intact.
2. Add a generic credential join that derives each identifier’s final segment,
   matches only equal suffixes, and binds the transaction graph identifier as
   the displayed match. The query comment documents the accepted ambiguity if
   different credential types use the same bytes.
3. Update the result normalisation only as needed to prefer the explicit
   transaction match while retaining the older match fields.
4. Add one focused browser regression using the real scoped Conway transaction
   and selected bundled Amaru book. It asserts both owner labels, both concrete
   transaction identifiers, and a pre-existing resolution.

## Project Structure

```text
docs/inspector/
├── src/FFI/RdfShapes.js            # fixed SPARQL lens and result normaliser
└── tests/tx-identify.spec.mjs      # packaged browser regression

specs/144-generic-hex-suffix-credential-resolution/
├── spec.md
├── plan.md
└── tasks.md
```

## Slice Plan

### Slice 1 — Resolve generic credential hashes

One bisect-safe implementation commit:

- Write a failing Playwright regression for the real transaction and the two
  known owner hashes, including an existing resolution assertion.
- Extend `resolvedLabelsQuery` and, if required, its normaliser so the test
  observes the concrete type-specific transaction identifiers as matches.
- Add query-local documentation for the accepted identical-bytes collision.
- Run `./gate.sh`; commit as
  `feat(inspector): resolve credentials by generic hex suffix` with
  `Tasks: T001, T002, T003`.

No follow-on UI rendering slice is planned: main-tab promotion is a stated
non-goal and `Main.purs` is owned by sibling epic children.
