{
  openapi = "3.1.0";
  info = {
    title = "Cardano Ledger WASI Functional API";
    summary = "Functional ledger-operation boundary for Cardano transaction tooling.";
    description = "This OpenAPI document describes the JSON control envelope used by host adapters around the Cardano Ledger WASI functional layer. The repository does not publish a stateful hosted service. WASI callers use the same request and response schemas through stdin/stdout; HTTP adapters can expose the POST shape documented here.";
    version = "0.1.0-draft";
    license = {
      name = "Apache-2.0";
      url = "https://github.com/lambdasistemi/cardano-ledger-inspector/blob/main/LICENSE";
    };
  };
  externalDocs = {
    description = "Functional API contract";
    url = "https://github.com/lambdasistemi/cardano-ledger-inspector/blob/main/specs/001-ledger-functional-layer/contracts/ledger-functional-api.md";
  };
  servers = [
    {
      url = "/";
      description = "Host adapter root. This repository publishes the contract and WASI artifact, not a public hosted ledger service.";
    }
  ];
  tags = [
    {
      name = "Ledger Operations";
      description = "Pure ledger-backed operations over explicit transaction CBOR and arguments.";
    }
  ];
  paths = {
    "/ledger/operations" = {
      post = {
        tags = [ "Ledger Operations" ];
        operationId = "runLedgerOperation";
        summary = "Run a ledger functional operation";
        description = "Run one ledger-backed function over the supplied transaction CBOR. The host owns workspace state and sends the current transaction bytes on every call. WASI command failures are reported through stderr and process status; HTTP host adapters should map those failures to the JSON error shape documented here.";
        requestBody = {
          required = true;
          content = {
            "application/json" = {
              schema = {
                "$ref" = "ledger-operation-request.schema.json";
              };
              examples = {
                inspect = {
                  summary = "Inspect a transaction";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.inspect";
                    args = { };
                  };
                };
                browse = {
                  summary = "Browse a nested transaction value";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.browse";
                    args = {
                      path = [
                        "body"
                        "outputs"
                        "#0"
                      ];
                    };
                  };
                };
                identify = {
                  summary = "Identify a transaction";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.identify";
                    args = { };
                  };
                };
                intent = {
                  summary = "Summarize signer-visible transaction intent";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.intent";
                    args = {
                      input_policy = "preserve";
                    };
                  };
                };
                witnessPlan = {
                  summary = "Plan transaction witnesses";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.witness.plan";
                    args = {
                      input_policy = "preserve";
                      context = {
                        producer_txs = {
                          "0000000000000000000000000000000000000000000000000000000000000000" = {
                            tx_cbor = "84a4...";
                            source = "blockfrost.txs.cbor";
                          };
                        };
                        resolution = {
                          provider = "blockfrost";
                          source = "tx-cbor";
                          requested_input_count = 1;
                          requested_reference_input_count = 0;
                          requested_tx_count = 1;
                          resolved_count = 1;
                          missing = [ ];
                          errors = [ ];
                          unspent_status = "not_checked";
                        };
                      };
                    };
                  };
                };
                witnessAttach = {
                  summary = "Attach or replace one vkey witness";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.witness.attach";
                    args = {
                      vkey_witness_cbor_hex = "825820000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f5840202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f";
                    };
                  };
                };
                validate = {
                  summary = "Validate a transaction or report missing context";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.validate";
                    args = {
                      input_policy = "preserve";
                      context = {
                        producer_txs = {
                          "0000000000000000000000000000000000000000000000000000000000000000" = {
                            tx_cbor = "84a4...";
                            source = "blockfrost.txs.cbor";
                          };
                        };
                        network = "mainnet";
                        slot = "123456789";
                        epoch = "507";
                        protocol_parameters = {
                          "_shape" = "complete Cardano.Ledger.Core.PParams ConwayEra JSON";
                        };
                      };
                    };
                  };
                };
                evaluateScripts = {
                  summary = "Evaluate phase-2 scripts or report missing context";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.evaluate.scripts";
                    args = {
                      input_policy = "preserve";
                      context = {
                        producer_txs = {
                          "0000000000000000000000000000000000000000000000000000000000000000" = {
                            tx_cbor = "84a4...";
                            source = "blockfrost.txs.cbor";
                          };
                        };
                        network = "mainnet";
                        slot = "123456789";
                        epoch = "507";
                        protocol_parameters = {
                          "_shape" = "complete Cardano.Ledger.Core.PParams ConwayEra JSON";
                        };
                      };
                    };
                  };
                };
                balance = {
                  summary = "Target shape for best-effort balancing";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.balance";
                    args = {
                      network = "mainnet";
                      slot = 0;
                      protocol_parameters = { };
                      utxo = { };
                      change = {
                        address = "addr1...";
                        policy = "preserve-existing-or-add";
                      };
                      constraints = {
                        max_extra_inputs = 0;
                        allow_output_reordering = false;
                        allow_collateral_change = true;
                      };
                    };
                  };
                };
              };
            };
          };
        };
        responses = {
          "200" = {
            description = "Successful ledger operation response.";
            content = {
              "application/json" = {
                schema = {
                  "$ref" = "ledger-operation-response.schema.json";
                };
                examples = {
                  inspect = {
                    summary = "Inspection response envelope";
                    value = {
                      ledger_functional_layer = "cardano-ledger-functional/v1";
                      op = "tx.inspect";
                      result = {
                        inspection = {
                          era = "Conway";
                          fee_lovelace = "0";
                        };
                        browser = {
                          valid = true;
                          title = "tx";
                          subtitle = "object / 10 fields";
                          currentPath = "[]";
                          currentJson = "{}";
                          breadcrumbs = [
                            {
                              label = "tx";
                              path = "[]";
                            }
                          ];
                          rows = [ ];
                        };
                      };
                    };
                  };
                  identify = {
                    summary = "Identity response envelope";
                    value = {
                      ledger_functional_layer = "cardano-ledger-functional/v1";
                      op = "tx.identify";
                      result = {
                        identification = {
                          era = "Conway";
                          tx_id = "0000000000000000000000000000000000000000000000000000000000000000";
                          body_hash = "1111111111111111111111111111111111111111111111111111111111111111";
                          tx_size_bytes = 1234;
                          fee_lovelace = "0";
                          input_count = 1;
                          reference_input_count = 0;
                          output_count = 2;
                          cert_count = 0;
                          withdrawal_count = 0;
                          required_signer_count = 1;
                          witness_counts = {
                            vkey = 1;
                            bootstrap = 0;
                            native_script = 0;
                            plutus_v1 = 0;
                            plutus_v2 = 0;
                            plutus_v3 = 0;
                            redeemer = 0;
                            datum = 0;
                          };
                        };
                      };
                    };
                  };
                  intent = {
                    summary = "Signer-focused intent response envelope";
                    value = {
                      ledger_functional_layer = "cardano-ledger-functional/v1";
                      op = "tx.intent";
                      result = {
                        intent = {
                          title = "Signing summary";
                          subtitle = "1 metadata claim / 2 missing required signers / 2 redeemers";
                          tx_id = "0000000000000000000000000000000000000000000000000000000000000000";
                          body_hash = "1111111111111111111111111111111111111111111111111111111111111111";
                          fee_lovelace = "1043795";
                          input_policy = "preserve";
                          metrics = [
                            {
                              label = "Fee";
                              value = "1.043795 ADA";
                            }
                            {
                              label = "Signer net ADA";
                              value = "unknown";
                            }
                            {
                              label = "Missing signers";
                              value = "2 missing required signers";
                            }
                          ];
                          claims = [
                            {
                              label = "Swap ADA<->USDM";
                              value = "Swapping ADA for $100k at a rate of $0.245 per ADA";
                              detail = "Required to pay Antithesis as vendor / destination Network Compliance's treasury / metadata label 1694 / self-declared";
                            }
                          ];
                          auxiliary_data = {
                            metadata = [
                              {
                                label = "1694";
                                value = {
                                  type = "map";
                                  entries = [
                                    {
                                      key = { type = "text"; value = "label"; };
                                      value = { type = "text"; value = "Swap ADA<->USDM"; };
                                    }
                                  ];
                                };
                              }
                            ];
                          };
                          sections = [
                            {
                              title = "Signer value perspective";
                              empty = "No signer value perspective available.";
                              rows = [
                                {
                                  label = "Net signer ADA";
                                  value = "unknown";
                                  path = "[\"intent\",\"value\",\"signer_perspective\",\"#0\"]";
                                  copyValue = "unknown";
                                  detail = "producer transaction CBOR must resolve every regular input before signer net can be known";
                                }
                              ];
                            }
                            {
                              title = "Critical effects";
                              empty = "No transaction effects reported.";
                              rows = [ ];
                            }
                            {
                              title = "Declared required signers";
                              empty = "No declared required signers.";
                              rows = [
                                {
                                  label = "declared required signer";
                                  value = "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1";
                                  path = "[\"intent\",\"signing\",\"required_signers\",\"#0\",\"hash\"]";
                                  copyValue = "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1";
                                  detail = "declared required signer not present in vkey or bootstrap witnesses";
                                }
                              ];
                            }
                            {
                              title = "Missing required signers";
                              empty = "None missing.";
                              rows = [
                                {
                                  label = "declared required signer not present in vkey or bootstrap witnesses";
                                  value = "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1";
                                  path = "[\"intent\",\"signing\",\"missing_vkey_witnesses\",\"#0\",\"hash\"]";
                                  copyValue = "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1";
                                  detail = "declared required signer not present in vkey or bootstrap witnesses";
                                }
                              ];
                            }
                          ];
                          signing = {
                            missing_vkey_witness_count = 2;
                            missing_vkey_witnesses = [
                              {
                                hash = "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1";
                                reason = "declared required signer not present in vkey or bootstrap witnesses";
                              }
                            ];
                            present_bootstrap_witness_count = 0;
                            present_bootstrap_witnesses = [ ];
                            present_vkey_witness_count = 0;
                            present_vkey_witnesses = [ ];
                            required_signer_count = 2;
                            required_signers = [
                              {
                                hash = "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1";
                                source = "tx_body.required_signers";
                                witness_status = "missing";
                              }
                              {
                                hash = "f3ab64b0f97dcf0f91232754603283df5d75a1201337432c04d23e2e";
                                source = "tx_body.required_signers";
                                witness_status = "missing";
                              }
                            ];
                          };
                          withdrawals = [
                            {
                              index = 0;
                              reward_account_hex = "f1a64d1b9e1aeffe54056034d84977061b45a92691efc282fbee3fc094";
                              network = "mainnet";
                              credential = {
                                kind = "script";
                                hash = "a64d1b9e1aeffe54056034d84977061b45a92691efc282fbee3fc094";
                              };
                              amount_lovelace = "0";
                            }
                          ];
                          value = {
                            net_spend_known = false;
                            net_spend_note = "Signer net is unknown until producer transaction CBOR resolves every regular input; output totals are still ledger facts.";
                            signer_lovelace = {
                              known = false;
                              resolved_input_lovelace = "0";
                              output_lovelace = "0";
                              external_or_script_output_lovelace = "1212430755481";
                              net_lovelace = null;
                              basis = "payment key credentials matching declared required signers or present key witnesses";
                            };
                            resolved_input_buckets = [ ];
                            output_buckets = [
                              {
                                bucket = "script";
                                label = "Script";
                                tx_out_count = 11;
                                lovelace = "1162532800000";
                                asset_class_count = 0;
                              }
                            ];
                          };
                          warnings = [
                            "Metadata describes intent but is self-declared; verify it against the destination addresses and contract policy."
                          ];
                        };
                      };
                    };
                  };
                  witnessPlan = {
                    summary = "Witness plan response envelope";
                    value = {
                      ledger_functional_layer = "cardano-ledger-functional/v1";
                      op = "tx.witness.plan";
                      result = {
                        witness_plan = {
                          required_signers = [ ];
                          present_vkey_witnesses = [
                            {
                              hash = "00000000000000000000000000000000000000000000000000000000";
                              source = "witness_set.vkey";
                            }
                          ];
                          present_bootstrap_witnesses = [ ];
                          missing_vkey_witnesses = [ ];
                          scripts = [ ];
                          redeemers = [
                            {
                              purpose = "ConwayMinting (AsIx {unAsIx = 0})";
                              redeemer_data_hash = "2222222222222222222222222222222222222222222222222222222222222222";
                              ex_units = {
                                memory = 1;
                                steps = 1;
                              };
                            }
                          ];
                          datums = [ ];
                          reference_inputs = [ ];
                          resolved_inputs = [
                            {
                              key = "0000000000000000000000000000000000000000000000000000000000000000#0";
                              tx_id = "0000000000000000000000000000000000000000000000000000000000000000";
                              index = 0;
                              resolved = true;
                              source = "blockfrost.txs.cbor";
                              tx_out = {
                                address_hex = "01...";
                                coin_lovelace = "10000000";
                                assets = { };
                                datum = {
                                  kind = "no_datum";
                                };
                              };
                            }
                          ];
                          resolved_reference_inputs = [ ];
                          context = {
                            input_policy = "preserve";
                            producer_tx_count = 1;
                            decoded_producer_tx_count = 1;
                            producer_tx_errors = [ ];
                            supplied = true;
                            complete = true;
                            input_count = 1;
                            resolved_input_count = 1;
                            missing_input_count = 0;
                            reference_input_count = 0;
                            resolved_reference_input_count = 0;
                            missing_reference_input_count = 0;
                            resolution = {
                              provider = "blockfrost";
                              source = "tx-cbor";
                              requested_input_count = 1;
                              requested_reference_input_count = 0;
                              requested_tx_count = 1;
                              resolved_count = 1;
                              missing = [ ];
                              errors = [ ];
                              unspent_status = "not_checked";
                            };
                          };
                          summary = {
                            required_signer_count = 0;
                            present_vkey_witness_count = 1;
                            present_bootstrap_witness_count = 0;
                            missing_vkey_witness_count = 0;
                            script_count = 0;
                            redeemer_count = 1;
                            datum_count = 0;
                            reference_input_count = 0;
                          };
                          warnings = [
                            "Producer transaction CBOR resolved every visible transaction input; live unspent status is not checked by this operation."
                          ];
                        };
                      };
                    };
                  };
                  witnessAttach = {
                    summary = "Witness attachment response envelope";
                    value = {
                      ledger_functional_layer = "cardano-ledger-functional/v1";
                      op = "tx.witness.attach";
                      result = {
                        tx_cbor = "84a4...";
                        witness_attachment = {
                          status = "applied";
                          tx_id = "0000000000000000000000000000000000000000000000000000000000000000";
                          body_hash = "1111111111111111111111111111111111111111111111111111111111111111";
                          tx_cbor = "84a4...";
                          signed_tx_cbor_hex = "84a4...";
                          witness_patch_action = "inserted";
                          errors = [ ];
                          warnings = [ ];
                        };
                      };
                    };
                  };
                  witnessAttachRejected = {
                    summary = "Rejected witness attachment with stable diagnostics";
                    value = {
                      ledger_functional_layer = "cardano-ledger-functional/v1";
                      op = "tx.witness.attach";
                      result = {
                        witness_attachment = {
                          status = "rejected";
                          tx_id = "0000000000000000000000000000000000000000000000000000000000000000";
                          body_hash = "1111111111111111111111111111111111111111111111111111111111111111";
                          errors = [
                            {
                              code = "missing_vkey_witness_cbor_hex";
                              message = "Supply args.vkey_witness_cbor_hex as hex-encoded CBOR for a single vkey witness.";
                              path = [
                                "args"
                                "vkey_witness_cbor_hex"
                              ];
                              details = null;
                            }
                          ];
                          warnings = [ ];
                        };
                      };
                    };
                  };
                  patch = {
                    summary = "Target shape for a transforming operation";
                    value = {
                      ledger_functional_layer = "cardano-ledger-functional/v1";
                      op = "tx.patch";
                      result = {
                        tx_cbor = "84a4...";
                        changes = [ ];
                        warnings = [ ];
                      };
                    };
                  };
                  validate = {
                    summary = "Validation response envelope";
                    value = {
                      ledger_functional_layer = "cardano-ledger-functional/v1";
                      op = "tx.validate";
                      result = {
                        validation = {
                          status = "incomplete";
                          valid_for_supplied_context = null;
                          complete = false;
                          tx_id = "0000000000000000000000000000000000000000000000000000000000000000";
                          body_hash = "1111111111111111111111111111111111111111111111111111111111111111";
                          checks = [
                            {
                              id = "ledger.apply_tx";
                              title = "Conway ledger validation";
                              status = "not_evaluated";
                              scope = "ledger";
                              required_context = [
                                "source_output"
                                "protocol_parameters"
                                "slot"
                                "epoch"
                                "network"
                              ];
                              path = [ "args" "context" ];
                              message = "Validation needs explicit context before Conway applyTx can run.";
                            }
                          ];
                          failures = [
                            {
                              kind = "ledger_failure";
                              rule = "UTXOW";
                              index = 0;
                              message = "Transaction witness or UTxO validation failed: <ledger predicate>";
                              predicate = "<raw Conway ledger predicate>";
                              path = [ "body" ];
                            }
                          ];
                          missing_context = [
                            {
                              kind = "source_output";
                              message = "Supply producer transaction CBOR for the referenced transaction input.";
                              path = [ "args" "context" "producer_txs" ];
                              tx_id = "0000000000000000000000000000000000000000000000000000000000000000";
                              index = 0;
                              required_for = [ "ledger.apply_tx" ];
                            }
                          ];
                          resolved_inputs = [ ];
                          resolved_reference_inputs = [ ];
                          context = {
                            input_policy = "preserve";
                            producer_tx_count = 0;
                            decoded_producer_tx_count = 0;
                            input_count = 1;
                            resolved_input_count = 0;
                            missing_input_count = 1;
                            reference_input_count = 0;
                            resolved_reference_input_count = 0;
                            missing_reference_input_count = 0;
                            unspent_status = "not_checked";
                          };
                          warnings = [ ];
                          errors = [ ];
                        };
                      };
                    };
                  };
                  evaluateScripts = {
                    summary = "Script evaluation response envelope";
                    value = {
                      ledger_functional_layer = "cardano-ledger-functional/v1";
                      op = "tx.evaluate.scripts";
                      result = {
                        script_evaluation = {
                          status = "incomplete";
                          scripts_evaluate_for_supplied_context = null;
                          complete = false;
                          tx_id = "0000000000000000000000000000000000000000000000000000000000000000";
                          body_hash = "1111111111111111111111111111111111111111111111111111111111111111";
                          redeemers = [
                            {
                              key = "spend#0";
                              purpose = "spend";
                              index = 0;
                              status = "not_evaluated";
                              path = [
                                "body"
                                "inputs"
                                "#0"
                              ];
                              redeemer_data_hash = "2222222222222222222222222222222222222222222222222222222222222222";
                              budget_ex_units = {
                                memory = "1000000";
                                steps = "500000000";
                              };
                              evaluated_ex_units = null;
                              missing_context = [ "source_output" ];
                              warnings = [ ];
                            }
                          ];
                          total_ex_units = {
                            memory = "0";
                            steps = "0";
                            partial = true;
                          };
                          failures = [ ];
                          missing_context = [
                            {
                              kind = "source_output";
                              message = "Supply producer transaction CBOR for the referenced transaction input.";
                              path = [
                                "body"
                                "inputs"
                                "#0"
                              ];
                              tx_id = "0000000000000000000000000000000000000000000000000000000000000000";
                              index = 0;
                              input_kind = "input";
                              required_for = [ "script.evaluate" ];
                            }
                          ];
                          resolved_inputs = [ ];
                          resolved_reference_inputs = [ ];
                          context = {
                            input_policy = "preserve";
                            producer_tx_count = 0;
                            decoded_producer_tx_count = 0;
                            redeemer_count = 1;
                            evaluated_redeemer_count = 0;
                            unspent_status = "not_checked";
                          };
                          warnings = [ ];
                          errors = [ ];
                        };
                      };
                    };
                  };
                };
              };
            };
          };
          "400" = {
            description = "Malformed request, malformed transaction bytes, or ledger operation failure.";
            content = {
              "application/json" = {
                schema = {
                  "$ref" = "#/components/schemas/LedgerOperationError";
                };
                examples = {
                  unknownOperation = {
                    summary = "Unknown operation";
                    value = {
                      error = {
                        category = "unknown_ledger_operation";
                        detail = "tx.unknown";
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
  components = {
    schemas = {
      LedgerOperationRequest = {
        "$ref" = "ledger-operation-request.schema.json";
      };
      LedgerOperationResponse = {
        "$ref" = "ledger-operation-response.schema.json";
      };
      BrowserView = {
        "$ref" = "browser-view.schema.json";
      };
      TxIdentifyResult = {
        "$ref" = "tx-identify-result.schema.json";
      };
      TxIntentResult = {
        "$ref" = "tx-intent-result.schema.json";
      };
      TxWitnessPlanResult = {
        "$ref" = "tx-witness-plan-result.schema.json";
      };
      TxWitnessAttachResult = {
        "$ref" = "tx-witness-attach-result.schema.json";
      };
      TxValidateResult = {
        "$ref" = "tx-validate-result.schema.json";
      };
      TxEvaluateScriptsResult = {
        "$ref" = "tx-evaluate-scripts-result.schema.json";
      };
      ProducerTxContext = {
        "$ref" = "producer-tx-context.schema.json";
      };
      LedgerOperationError = {
        type = "object";
        required = [ "error" ];
        properties = {
          error = {
            type = "object";
            required = [
              "category"
              "detail"
            ];
            properties = {
              category = {
                type = "string";
                enum = [
                  "malformed_hex"
                  "malformed_cbor"
                  "malformed_ledger_operation"
                  "unknown_ledger_operation"
                  "ledger_operation_failed"
                  "missing_context"
                ];
              };
              detail = {
                type = "string";
              };
            };
            additionalProperties = true;
          };
        };
        additionalProperties = true;
      };
    };
  };
}
