{
  description = "Cardano ledger operations compiled to WASI";

  nixConfig = {
    extra-substituters = [ "https://cache.iog.io" ];
    extra-trusted-public-keys =
      [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
  };

  inputs = {
    haskellNix = {
      url = "github:input-output-hk/haskell.nix/ef52c36b9835c77a255befe2a20075ba71e3bfab";
      inputs.hackage.follows = "hackageNix";
    };
    hackageNix = {
      url = "github:input-output-hk/hackage.nix/c3d44f9e5d929e86a45a48246667ea25cd1f11df";
      flake = false;
    };
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    iohkNix = {
      url = "github:input-output-hk/iohk-nix/f444d972c301ddd9f23eac4325ffcc8b5766eee9";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    CHaP = {
      url = "github:intersectmbo/cardano-haskell-packages/00c90c10812a98ef9680f4bfa269d42366d46d89";
      flake = false;
    };
    ghc-wasm-meta = {
      url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
    };
    purescript-overlay = {
      url = "github:paolino/purescript-overlay/fix/remove-nodePackages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mkSpagoDerivation = {
      url = "github:jeslie0/mkSpagoDerivation";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@
    { self
    , nixpkgs
    , flake-parts
    , haskellNix
    , iohkNix
    , CHaP
    , ghc-wasm-meta
    , purescript-overlay
    , mkSpagoDerivation
    , ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ];

      flake = {
        lib.wasm = import ./nix/wasm { lib = nixpkgs.lib; };
      };

      perSystem =
        { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              iohkNix.overlays.crypto
              haskellNix.overlay
              iohkNix.overlays.haskell-nix-crypto
              iohkNix.overlays.cardano-lib
            ];
          };

          psPkgs = import nixpkgs {
            inherit system;
            overlays = [
              purescript-overlay.overlays.default
              mkSpagoDerivation.overlays.default
            ];
          };

          mkdocsEnv = pkgs.python3.withPackages (
            ps: with ps; [
              mkdocs
              mkdocs-material
              pymdown-extensions
            ]
          );

          hostTargets = import ./nix/host { inherit pkgs CHaP; };

          wasmTargets = import ./nix/wasm-targets.nix {
            inherit pkgs;
            libWasm = self.lib.wasm;
            ghcWasmMeta = ghc-wasm-meta.packages.${system}.all_9_12;
            wasiSdk = ghc-wasm-meta.packages.${system}.wasi-sdk;
            chap = CHaP;
            smokeSrc = ./nix/wasm/smoke;
            ledgerSmokeSrc = ./nix/wasm/ledger-smoke;
            txInspectorSrc = ./libs/cardano-ledger-inspector;
            extismSpikeSrc = ./.;
          };

          tx-inspector-ui = import ./nix/wasm-ui.nix {
            inherit system nixpkgs purescript-overlay mkSpagoDerivation;
            wasmArtifact = wasmTargets.wasm-tx-inspector;
            wasmArtifactName = "wasm-tx-inspector";
            src = ./docs/inspector;
          };

          ledgerFunctionalOpenapiSpec = import ./nix/ledger-functional-openapi.nix;

          ledgerFunctionalOpenapiSource = pkgs.writeText
            "cardano-ledger-functional.openapi.raw.json"
            (builtins.toJSON ledgerFunctionalOpenapiSpec);

          ledger-functional-openapi-generated =
            pkgs.runCommand "ledger-functional-openapi-generated" { } ''
              mkdir -p $out
              ${pkgs.jq}/bin/jq --sort-keys . ${ledgerFunctionalOpenapiSource} \
                > $out/cardano-ledger-functional.openapi.json
            '';

          ledger-functional-openapi = pkgs.runCommand "ledger-functional-openapi" { } ''
            mkdir -p $out
            cp ${ledger-functional-openapi-generated}/cardano-ledger-functional.openapi.json \
              $out/cardano-ledger-functional.openapi.json
            cp ${./specs/001-ledger-functional-layer/schemas}/*.json $out/
          '';

          ledger-functional-openapi-check =
            pkgs.runCommand "ledger-functional-openapi-check" { } ''
              mkdir -p generated $out
              cp ${ledger-functional-openapi-generated}/cardano-ledger-functional.openapi.json \
                generated/cardano-ledger-functional.openapi.json
              ${pkgs.diffutils}/bin/diff -u \
                ${./specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json} \
                generated/cardano-ledger-functional.openapi.json
              touch $out/passed
            '';

          tx-identify-smoke = pkgs.runCommand "tx-identify-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.identify",
                args: {}
              }' > request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.identify"
              and (.result.identification.tx_id | test("^[0-9a-f]{64}$"))
              and (.result.identification.body_hash | test("^[0-9a-f]{64}$"))
              and (.result.identification.tx_size_bytes > 0)
              and (.result.identification.fee_lovelace | test("^[0-9]+$"))
              and (.result.identification.witness_counts.vkey >= 0)
              and (.result.identification.witness_counts.bootstrap >= 0)
            ' response.json
            cp request.json response.json $out/
          '';

          tx-witness-plan-smoke = pkgs.runCommand "tx-witness-plan-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.witness.plan",
                args: {}
              }' > request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.witness.plan"
              and (.result.witness_plan.required_signers | type == "array")
              and (.result.witness_plan.present_vkey_witnesses | type == "array")
              and (.result.witness_plan.present_bootstrap_witnesses | type == "array")
              and (.result.witness_plan.missing_vkey_witnesses | type == "array")
              and (.result.witness_plan.scripts | type == "array")
              and (.result.witness_plan.redeemers | type == "array")
              and (.result.witness_plan.datums | type == "array")
              and (.result.witness_plan.reference_inputs | type == "array")
              and (.result.witness_plan.resolved_inputs | type == "array")
              and (.result.witness_plan.resolved_reference_inputs | type == "array")
              and .result.witness_plan.context.supplied == false
              and .result.witness_plan.context.producer_tx_count == 0
              and (.result.witness_plan.summary.required_signer_count >= 0)
              and (.result.witness_plan.summary.present_vkey_witness_count >= 0)
              and (.result.witness_plan.summary.missing_vkey_witness_count >= 0)
              and (.result.witness_plan.warnings | length >= 1)
            ' response.json
            cp request.json response.json $out/
          '';

          tx-intent-smoke = pkgs.runCommand "tx-intent-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq '.op = "tx.intent"' \
              ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.intent"
              and any(.result.intent.metrics[]; .label == "Signer net ADA" and .value == "-5.900913 ADA")
              and .result.intent.sections[0].title == "Signer value perspective"
              and .result.intent.value.net_spend_known == true
              and .result.intent.value.signer_lovelace.known == true
              and .result.intent.value.signer_lovelace.net_lovelace == "-5900913"
              and any(.result.intent.value.resolved_input_buckets[]; .bucket == "signer_controlled" and .lovelace == "7015148761")
              and any(.result.intent.value.output_buckets[]; .bucket == "signer_controlled" and .lovelace == "7009247848")
              and any(.result.intent.value.output_buckets[]; .bucket == "script" and .tx_out_count == 4)
            ' response.json
            cp request.json response.json $out/
          '';

          tx-input-context-smoke = pkgs.runCommand "tx-input-context-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.inspect",
                args: {}
              }' > inspect-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < inspect-request.json > inspect-response.json
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              --slurpfile inspect inspect-response.json \
              '$inspect[0].result.inspection as $inspection
              | ($inspection.inputs + $inspection.reference_inputs) as $inputs
              | ($inputs | map(.tx_id) | unique) as $producerTxIds
              | {
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.witness.plan",
                args: {
                  input_policy: "preserve",
                  context: {
                    producer_txs: (
                      $producerTxIds
                      | map({
                          key: .,
                          value: {
                            tx_cbor: ($tx | gsub("\\s"; "")),
                            source: "smoke.synthetic.current_tx_cbor"
                          }
                        })
                      | from_entries
                    ),
                    resolution: {
                      provider: "smoke",
                      source: "synthetic-producer-tx-cbor",
                      requested_input_count: ($inspection.inputs | length),
                      requested_reference_input_count: ($inspection.reference_inputs | length),
                      requested_tx_count: ($producerTxIds | length),
                      resolved_count: ($producerTxIds | length),
                      missing: [],
                      errors: [],
                      unspent_status: "not_checked"
                    }
                  }
                }
              }' > request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < request.json > response.json
            ${pkgs.jq}/bin/jq -e '
              .result.witness_plan as $plan
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.witness.plan"
              and $plan.context.input_policy == "preserve"
              and $plan.context.supplied == true
              and $plan.context.producer_tx_count > 0
              and $plan.context.decoded_producer_tx_count == $plan.context.producer_tx_count
              and $plan.context.complete == true
              and $plan.context.missing_input_count == 0
              and ($plan.resolved_inputs | length == $plan.context.input_count)
              and ([$plan.resolved_inputs[]? | select(.resolved != true)] | length == 0)
            ' response.json
            cp inspect-request.json inspect-response.json request.json response.json $out/
          '';

          tx-validate-smoke = pkgs.runCommand "tx-validate-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.validate",
                args: {
                  input_policy: "preserve",
                  context: {}
                }
              }' > missing-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < missing-context-request.json > missing-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.validate"
              and $v.status == "incomplete"
              and $v.valid_for_supplied_context == null
              and $v.complete == false
              and ($v.tx_id | test("^[0-9a-f]{64}$"))
              and ($v.body_hash | test("^[0-9a-f]{64}$"))
              and ($v.checks | type == "array")
              and ([$v.checks[]? | select(.id == "ledger.apply_tx" and .status == "not_evaluated")] | length == 1)
              and ($v.failures | type == "array")
              and ($v.failures | length == 0)
              and ($v.missing_context | type == "array")
              and ($v.missing_context | length >= 1)
              and ([$v.missing_context[]? | select(.kind == "source_output")] | length >= 1)
              and ($v.resolved_inputs | type == "array")
              and ($v.resolved_reference_inputs | type == "array")
              and $v.context.input_policy == "preserve"
              and $v.context.producer_tx_count == 0
              and (.result | has("tx_cbor") | not)
            ' missing-context-response.json

            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.validate",
                args: {
                  input_policy: "preserve",
                  context: {
                    utxo: {}
                  }
                }
              }' > malformed-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < malformed-context-request.json > malformed-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .op == "tx.validate"
              and $v.status == "rejected"
              and $v.valid_for_supplied_context == null
              and ($v.errors | type == "array")
              and ([$v.errors[]? | select(.code == "unsupported_utxo_json")] | length == 1)
              and ($v.failures | length == 0)
              and (.result | has("tx_cbor") | not)
            ' malformed-context-response.json

            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} > complete-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.validate"
              and $v.status == "valid"
              and $v.valid_for_supplied_context == true
              and $v.complete == true
              and ($v.errors | length == 0)
              and ($v.failures | length == 0)
              and ($v.missing_context | length == 0)
              and $v.context.complete == true
              and $v.context.resolved_input_count == $v.context.input_count
              and $v.context.resolved_reference_input_count == $v.context.reference_input_count
              and ([$v.checks[]? | select(.id == "ledger.apply_tx" and .status == "passed")] | length == 1)
              and (.result | has("tx_cbor") | not)
            ' complete-context-response.json

            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} > complete-context-response-2.json
            ${pkgs.jq}/bin/jq -s -e '
              .[0].result.validation == .[1].result.validation
            ' complete-context-response.json complete-context-response-2.json

            ${pkgs.jq}/bin/jq '.args.context.network = "testnet"' \
              ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > invalid-network-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < invalid-network-request.json > invalid-network-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .op == "tx.validate"
              and $v.status == "invalid"
              and $v.valid_for_supplied_context == false
              and $v.complete == true
              and ($v.errors | length == 0)
              and ($v.missing_context | length == 0)
              and ($v.failures | length > 0)
              and ([$v.checks[]? | select(.id == "ledger.apply_tx" and .status == "failed")] | length == 1)
              and (.result | has("tx_cbor") | not)
            ' invalid-network-response.json
            cp missing-context-request.json missing-context-response.json \
              malformed-context-request.json malformed-context-response.json \
              ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              complete-context-response.json complete-context-response-2.json \
              invalid-network-request.json invalid-network-response.json $out/
          '';

          tx-evaluate-scripts-smoke = pkgs.runCommand "tx-evaluate-scripts-smoke" { } ''
            mkdir -p $out
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.evaluate.scripts",
                args: {
                  input_policy: "preserve",
                  context: {}
                }
              }' > missing-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < missing-context-request.json > missing-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.script_evaluation as $e
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.evaluate.scripts"
              and $e.status == "incomplete"
              and $e.scripts_evaluate_for_supplied_context == null
              and $e.complete == false
              and ($e.tx_id | test("^[0-9a-f]{64}$"))
              and ($e.body_hash | test("^[0-9a-f]{64}$"))
              and ($e.redeemers | type == "array")
              and ($e.redeemers | length >= 1)
              and ([$e.redeemers[]? | select(.status == "not_evaluated")] | length >= 1)
              and ([$e.redeemers[]? | select(.budget_ex_units.memory | test("^[0-9]+$"))] | length >= 1)
              and ($e.total_ex_units.memory | test("^[0-9]+$"))
              and ($e.total_ex_units.steps | test("^[0-9]+$"))
              and $e.total_ex_units.partial == true
              and ($e.failures | length == 0)
              and ($e.missing_context | length >= 1)
              and ([$e.missing_context[]? | select(.kind == "source_output")] | length >= 1)
              and ($e.resolved_inputs | type == "array")
              and ($e.resolved_reference_inputs | type == "array")
              and $e.context.input_policy == "preserve"
              and $e.context.producer_tx_count == 0
              and (.result | has("tx_cbor") | not)
            ' missing-context-response.json

            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.evaluate.scripts",
                args: {
                  input_policy: "preserve",
                  context: {
                    utxo: {}
                  }
                }
              }' > malformed-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < malformed-context-request.json > malformed-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.script_evaluation as $e
              | .op == "tx.evaluate.scripts"
              and $e.status == "rejected"
              and $e.scripts_evaluate_for_supplied_context == null
              and ($e.errors | type == "array")
              and ([$e.errors[]? | select(.code == "unsupported_utxo_json")] | length == 1)
              and ($e.failures | length == 0)
              and (.result | has("tx_cbor") | not)
            ' malformed-context-response.json

            cp ${./specs/001-ledger-functional-layer/fixtures/tx-evaluate-scripts-complete-request.json} \
              complete-context-request.json
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < complete-context-request.json > complete-context-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.script_evaluation as $e
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.evaluate.scripts"
              and $e.status == "succeeded"
              and $e.scripts_evaluate_for_supplied_context == true
              and $e.complete == true
              and ($e.errors | length == 0)
              and ($e.failures | length == 0)
              and ($e.missing_context | length == 0)
              and ($e.redeemers | length >= 1)
              and ([$e.redeemers[]? | select(.status == "succeeded")] | length == ($e.redeemers | length))
              and ([$e.redeemers[]? | select(.evaluated_ex_units.memory | test("^[0-9]+$"))] | length == ($e.redeemers | length))
              and ($e.total_ex_units.memory | test("^[0-9]+$"))
              and ($e.total_ex_units.steps | test("^[0-9]+$"))
              and $e.total_ex_units.partial == false
              and $e.context.complete == true
              and $e.context.evaluated_redeemer_count == $e.context.redeemer_count
              and (.result | has("tx_cbor") | not)
            ' complete-context-response.json

            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < complete-context-request.json > complete-context-response-2.json
            ${pkgs.jq}/bin/jq -s -e '
              .[0].result.script_evaluation == .[1].result.script_evaluation
            ' complete-context-response.json complete-context-response-2.json

            cp missing-context-request.json missing-context-response.json \
              malformed-context-request.json malformed-context-response.json \
              complete-context-request.json complete-context-response.json \
              complete-context-response-2.json $out/
          '';

          # Spike: native Haskell host (libextism + Wasmtime) loads the
          # plugin and calls ledger operation exports against Conway
          # fixtures. The Extism exports delegate to the same
          # runLedgerOperationInput as the WASI reactor, so responses
          # are byte-identical to the WASI reactor for the same
          # envelope.
          # The host is in nix/host/extism-spike-host; libextism is the
          # prebuilt Rust runtime fetched from the upstream release.
          tx-extism-spike-smoke = pkgs.runCommand "tx-extism-spike-smoke" { } ''
            mkdir -p $out
            # Wasmtime writes a compile cache; sandbox HOME is unwritable.
            export HOME="$PWD"
            export XDG_CACHE_HOME="$PWD/.cache"
            mkdir -p "$XDG_CACHE_HOME"

            HOST=${hostTargets.extism-spike-host}/bin/extism-spike-host
            WASM=${wasmTargets.wasm-extism-spike}/wasm-extism-spike.wasm

            # tx.identify
            ${pkgs.jq}/bin/jq -n \
              --rawfile tx ${./specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex} \
              '{
                ledger_functional_layer: "cardano-ledger-functional/v1",
                tx_cbor: ($tx | gsub("\\s"; "")),
                op: "tx.identify",
                args: {}
              }' > identify-request.json
            "$HOST" "$WASM" tx_identify \
              < identify-request.json > identify-response.json
            ${pkgs.jq}/bin/jq -e '
              .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.identify"
              and (.result.identification.tx_id | test("^[0-9a-f]{64}$"))
              and (.result.identification.body_hash | test("^[0-9a-f]{64}$"))
              and (.result.identification.tx_size_bytes > 0)
              and (.result.identification.fee_lovelace | test("^[0-9]+$"))
              and (.result.identification.witness_counts.vkey >= 0)
            ' identify-response.json

            # tx.validate - complete-context fixture (status=valid)
            "$HOST" "$WASM" tx_validate \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > validate-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.validation as $v
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.validate"
              and $v.status == "valid"
              and $v.valid_for_supplied_context == true
              and $v.complete == true
              and ($v.failures | length == 0)
              and ([$v.checks[]? | select(.id == "ledger.apply_tx" and .status == "passed")] | length == 1)
            ' validate-response.json

            # Conformance: Extism response on tx.validate is byte-identical
            # to the WASI reactor response on the same envelope.
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json} \
              > wasi-validate-response.json
            ${pkgs.jq}/bin/jq -s -e '.[0] == .[1]' \
              validate-response.json wasi-validate-response.json

            # tx.evaluate.scripts - complete-context fixture (status=succeeded)
            "$HOST" "$WASM" tx_evaluate_scripts \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-evaluate-scripts-complete-request.json} \
              > evaluate-scripts-response.json
            ${pkgs.jq}/bin/jq -e '
              .result.script_evaluation as $e
              | .ledger_functional_layer == "cardano-ledger-functional/v1"
              and .op == "tx.evaluate.scripts"
              and $e.status == "succeeded"
              and $e.scripts_evaluate_for_supplied_context == true
              and $e.complete == true
              and ($e.failures | length == 0)
              and ([$e.redeemers[]? | select(.status == "succeeded")] | length == ($e.redeemers | length))
            ' evaluate-scripts-response.json

            # Conformance: Extism response on tx.evaluate.scripts is
            # byte-identical to the WASI reactor response on the same envelope.
            ${pkgs.wasmtime}/bin/wasmtime \
              ${wasmTargets.wasm-tx-inspector}/wasm-tx-inspector.wasm \
              < ${./specs/001-ledger-functional-layer/fixtures/tx-evaluate-scripts-complete-request.json} \
              > wasi-evaluate-scripts-response.json
            ${pkgs.jq}/bin/jq -s -e '.[0] == .[1]' \
              evaluate-scripts-response.json wasi-evaluate-scripts-response.json

            cp identify-request.json identify-response.json \
              validate-response.json wasi-validate-response.json \
              evaluate-scripts-response.json wasi-evaluate-scripts-response.json \
              $out/
          '';

          # Snapshot harness for the explain-artifact renderers. Walks
          # apps/tx-deep-diagnosis/test/golden/<case>/ and asserts each
          # produced artifact equals expected/<file> byte-for-byte. The
          # binary calls only pure renderers — no ledger / no network.
          tx-explain-render-smoke = pkgs.runCommand "tx-explain-render-smoke"
            { LANG = "C.UTF-8"; LC_ALL = "C.UTF-8"; } ''
            mkdir -p $out
            ${hostTargets.tx-deep-diagnosis-render-snapshot}/bin/tx-deep-diagnosis-render-snapshot \
              ${./apps/tx-deep-diagnosis/test/golden} \
              | tee $out/snapshot.log
          '';
        in
        {
          packages = {
            inherit (wasmTargets)
              wasm-smoke wasm-ledger-smoke wasm-tx-inspector wasm-extism-spike;
            inherit (hostTargets) extism-spike-host libextism
              tx-deep-diagnosis tx-deep-diagnosis-render-snapshot;
            inherit
              ledger-functional-openapi
              ledger-functional-openapi-generated
              tx-inspector-ui
              ;
            ledger-functional-swagger = ledger-functional-openapi;
            default = tx-inspector-ui;
          };

          checks = {
            inherit
              ledger-functional-openapi-check
              tx-identify-smoke
              tx-witness-plan-smoke
              tx-intent-smoke
              tx-input-context-smoke
              tx-validate-smoke
              tx-evaluate-scripts-smoke
              tx-extism-spike-smoke
              tx-explain-render-smoke;
            ledger-functional-swagger-check = ledger-functional-openapi-check;
          };

          apps =
            let
              mkSmokeApp = name: smoke: pkgs.writeShellApplication {
                name = "${name}-runner";
                runtimeInputs = [ pkgs.coreutils ];
                text = ''
                  set -euo pipefail
                  echo "=== ${name} ==="
                  echo "smoke artifacts: ${smoke}"
                  if [ -f ${smoke}/request.json ]; then
                    echo "--- request.json ---"
                    cat ${smoke}/request.json
                  fi
                  echo
                  if [ -f ${smoke}/response.json ]; then
                    echo "--- response.json ---"
                    cat ${smoke}/response.json
                  fi
                '';
              };
              mkApp = drv: { type = "app"; program = pkgs.lib.getExe drv; };
              format-check = pkgs.writeShellApplication {
                name = "format-check";
                runtimeInputs = [
                  pkgs.haskellPackages.fourmolu
                  pkgs.findutils
                ];
                text = ''
                  find libs apps nix/wasm -type f -name '*.hs' \
                    -exec fourmolu -m check {} +
                '';
              };
              test-playwright = pkgs.writeShellApplication {
                name = "test-playwright";
                runtimeInputs = [
                  pkgs.playwright-test
                  pkgs.nodejs_20
                  pkgs.python3
                  pkgs.coreutils
                ];
                excludeShellChecks = [
                  "SC2046"
                  "SC2086"
                ];
                text = ''
                  set -euo pipefail
                  cd docs/inspector
                  ln -sfn \
                    $(dirname $(dirname $(readlink -f $(command -v playwright))))/lib/node_modules \
                    node_modules
                  TX_INSPECTOR_SITE_DIR=${tx-inspector-ui} \
                    PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers} \
                    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
                    playwright test --reporter=list
                '';
              };
            in
            {
              format-check = mkApp format-check;
              test-playwright = mkApp test-playwright;
              tx-identify-smoke =
                mkApp (mkSmokeApp "tx-identify-smoke" tx-identify-smoke);
              tx-witness-plan-smoke =
                mkApp (mkSmokeApp "tx-witness-plan-smoke" tx-witness-plan-smoke);
              tx-intent-smoke =
                mkApp (mkSmokeApp "tx-intent-smoke" tx-intent-smoke);
              tx-validate-smoke =
                mkApp (mkSmokeApp "tx-validate-smoke" tx-validate-smoke);
              tx-evaluate-scripts-smoke =
                mkApp (mkSmokeApp "tx-evaluate-scripts-smoke" tx-evaluate-scripts-smoke);
              tx-input-context-smoke =
                mkApp (mkSmokeApp "tx-input-context-smoke" tx-input-context-smoke);
              tx-extism-spike-smoke =
                mkApp (mkSmokeApp "tx-extism-spike-smoke" tx-extism-spike-smoke);
              tx-explain-render-smoke =
                mkApp (mkSmokeApp "tx-explain-render-smoke" tx-explain-render-smoke);
              ledger-functional-openapi-check =
                mkApp (mkSmokeApp "ledger-functional-openapi-check"
                  ledger-functional-openapi-check);
              ledger-functional-swagger-check =
                mkApp (mkSmokeApp "ledger-functional-swagger-check"
                  ledger-functional-openapi-check);
            };

          devShells.default = pkgs.mkShell {
            buildInputs = [
              pkgs.just
              pkgs.wasmtime
              pkgs.jq
              pkgs.curl
              pkgs.playwright-test
              pkgs.nixfmt-rfc-style
              pkgs.haskellPackages.fourmolu
              mkdocsEnv
              psPkgs.purs
              psPkgs.spago-unstable
              psPkgs.esbuild
              psPkgs.nodejs_20
            ];
            PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
            PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          };
        };
    };
}
