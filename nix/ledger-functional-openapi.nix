{
  openapi = "3.1.0";
  info = {
    title = "Cardano Ledger WASI Functional API";
    summary = "Functional ledger-operation boundary for Cardano transaction tooling.";
    description = "This OpenAPI document describes the JSON control envelope used by host adapters around the Cardano Ledger WASI functional layer. The repository does not publish a stateful hosted service. WASI callers use the same request and response schemas through stdin/stdout; HTTP adapters can expose the POST shape documented here.";
    version = "0.1.0-draft";
    license = {
      name = "Apache-2.0";
      url = "https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/LICENSE";
    };
  };
  externalDocs = {
    description = "Functional API contract";
    url = "https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/contracts/ledger-functional-api.md";
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
                witnessPlan = {
                  summary = "Plan transaction witnesses";
                  value = {
                    ledger_functional_layer = "cardano-ledger-functional/v1";
                    tx_cbor = "84a4...";
                    op = "tx.witness.plan";
                    args = { };
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
                            "Transaction-only witness plan: UTxO context was not supplied, so input address credentials, reference scripts, and datum requirements cannot be inferred."
                          ];
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
      TxWitnessPlanResult = {
        "$ref" = "tx-witness-plan-result.schema.json";
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
