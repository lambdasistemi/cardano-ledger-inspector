# Signing summary

_1 metadata claim / 2 missing required signers / 2 redeemers_

Tx id: `30723408902f540c29e2e0ec7cb0dc89a0024d00506b564e326b8fe10fd2a00f`

## Verdict

- 6/6 producer txs resolved, network=mainnet
- ledger validation: **invalid**

## Claims

| Label | Value | Detail |
|-------|-------|--------|
| Swap ADA<->USDM | Swapping ADA for $100k at a rate of $0.245 per ADA | Required to pay Antithesis as vendor / destination Network Compliance's treasury / metadata label 1694 / self-declared |

## Signer value perspective

| Label | Value | Detail |
|-------|-------|--------|
| Net signer ADA | unknown | producer transaction CBOR must resolve every regular input before signer net can be known |
| Signer-controlled inputs | unknown | 0 resolved source outputs matched signer payment key hashes out of 0 resolved inputs |
| Signer-controlled outputs | 0 ADA | 0 outputs matched signer payment key hashes out of 12 outputs |
| External/script outputs | 1212430.755481 ADA | outputs not controlled by declared or witnessed signer payment key hashes |

## Critical effects

| Label | Value | Detail |
|-------|-------|--------|
| Consumes inputs | 2 inputs | source outputs not supplied |
| Creates outputs | 12 outputs | 1212430755481 lovelace total across all outputs |
| Pays fee | 1043795 lovelace |  |
| Required signatures | 2 signers | 2 declared signers missing from witnesses |
| Scripts | 2 redeemers | 0 script witnesses |
| Reference inputs | 4 read-only inputs | reference inputs are available to scripts but are not spent |
| Withdrawals | 1 withdrawal |  |
| Mint/burn | No mint/burn |  |
| Collateral | 1 collateral input | total 1565693 lovelace / return 50005673583 lovelace |

## Missing required signers

| Label | Value | Detail |
|-------|-------|--------|
| declared required signer not present in vkey or bootstrap witnesses | 8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1 | declared required signer not present in vkey or bootstrap witnesses |
| declared required signer not present in vkey or bootstrap witnesses | f3ab64b0f97dcf0f91232754603283df5d75a1201337432c04d23e2e | declared required signer not present in vkey or bootstrap witnesses |

## Validation failures

| Rule | Message |
|------|---------|
| UTXOW | Transaction witness or UTxO validation failed: UtxoFailure (ValueNotConservedUTxO Mismatch (RelEQ) {supplied: MaryValue (Coin 1500007239276) (MultiAsset (fromList [])), expected: MaryValue (Coin 1212431799276) (MultiAsset (fromList []))}) |
| UTXOW | Transaction witness or UTxO validation failed: MissingVKeyWitnessesUTXOW (NonEmptySet (fromList [KeyHash {unKeyHash = "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1"},KeyHash {unKeyHash = "dea7197ac235d73e7f7b1a249bace6a833722415d88e91dec5d2626d"},KeyHash {unKeyHash = "f3ab64b0f97dcf0f91232754603283df5d75a1201337432c04d23e2e"}])) |

## Warnings

- Metadata describes intent but is self-declared; verify it against the destination addresses and contract policy.
- Declared required signer hashes are absent from the witness set.

## Parties

```mermaid
%% L1 — parties involved in tx 30723408902f540c29e2e0ec7cb0dc89a0024d00506b564e326b8fe10fd2a00f
flowchart LR
    classDef signer fill:#fff8dc,stroke:#cc9900,stroke-width:2px
    classDef inputAddr fill:#f0f0f0,stroke:#666
    classDef bucket fill:#e6f0ff,stroke:#3366cc
    classDef txBody fill:#fffefa,stroke:#000,stroke-width:2px
    tx["tx"]:::txBody
    I0["key d2626d"]:::inputAddr
    I0 -- consumed --> tx
    I1["Amaru Network Compliance treasury (0baa0d)"]:::inputAddr
    I1 -- consumed --> tx
    O0["External key (1 out, 49897955481 lovelace)"]:::bucket
    tx -- produces --> O0
    O1["Script (11 out, 1162532800000 lovelace)"]:::bucket
    tx -- produces --> O1
    S0["signer 8bd03209…b24fb1c1"]:::signer
    S0 -. required .-> tx
    S1["signer f3ab64b0…04d23e2e"]:::signer
    S1 -. required .-> tx
```

## Balance

### Inputs

| Source | ADA |
|--------|----:|
| input #0 — key d2626d | 50,007.239276 |
| input #1 — Amaru Network Compliance treasury (0baa0d) | 1,450,000.000000 |
| **Total inputs** | **1,500,007.239276** |

### Outputs + fee

| Destination | ADA |
|-------------|----:|
| External key bucket | 49,897.955481 |
| Script bucket | 1,162,532.800000 |
| fee | 1.043795 |
| **Total outputs + fee** | **1,212,431.799276** |

**Unaccounted: 287,575.440000 missing — `ValueNotConservedUTxO`**

## Topology

```mermaid
%% L3 — full topology for tx 30723408902f540c29e2e0ec7cb0dc89a0024d00506b564e326b8fe10fd2a00f
flowchart TD
    classDef body fill:#fffefa,stroke:#000,stroke-width:2px
    classDef bodyFail fill:#ffe6e6,stroke:#cc0000,stroke-width:2px
    classDef inputNode fill:#f0f0f0,stroke:#666
    classDef inputFail fill:#ffe6e6,stroke:#cc0000
    classDef refInput fill:#f8f8f0,stroke:#999,stroke-dasharray:4 4
    classDef collateral fill:#fff0f0,stroke:#aa6666
    classDef bucket fill:#e6f0ff,stroke:#3366cc
    classDef signer fill:#fff8dc,stroke:#cc9900
    classDef signerFail fill:#ffe6e6,stroke:#cc0000,stroke-width:2px
    body["tx body\nfee 1043795 lovelace\nredeemers 2\nwithdrawals 1\nno mint/burn\ncollateral 1"]:::bodyFail
    in0["input #0\nkey d2626d\n50007239276 lovelace"]:::inputNode
    in0 --> body
    in1["input #1\nAmaru Network Compliance treasury (0baa0d)\n1450000000000 lovelace"]:::inputNode
    in1 --> body
    out0["External key bucket\n1 outputs / 49897955481 lovelace"]:::bucket
    body --> out0
    out1["Script bucket\n11 outputs / 1162532800000 lovelace"]:::bucket
    body --> out1
    ref0["ref #0\n5a7350fe…35614365"]:::refInput
    ref0 -. read .-> body
    ref1["ref #1\nkey e15954"]:::refInput
    ref1 -. read .-> body
    ref2["ref #2\nkey e15954"]:::refInput
    ref2 -. read .-> body
    ref3["ref #3\nnetwork_compliance registry"]:::refInput
    ref3 -. read .-> body
    coll["collateral input"]:::collateral
    coll -. fee guard .-> body
    collret["collateral return"]:::collateral
    body -. on script fail .-> collret
    sig0["signer 8bd03209…b24fb1c1"]:::signerFail
    sig0 -. required .-> body
    sig1["signer f3ab64b0…04d23e2e"]:::signerFail
    sig1 -. required .-> body
```

## Failure overlay

```mermaid
%% L4 — failures for tx 30723408902f540c29e2e0ec7cb0dc89a0024d00506b564e326b8fe10fd2a00f
flowchart TD
    classDef body fill:#fff,stroke:#000
    classDef bodyFail fill:#ffe6e6,stroke:#cc0000,stroke-width:2px
    classDef signerFail fill:#ffe6e6,stroke:#cc0000,stroke-width:2px
    classDef ruleFail fill:#fff0f0,stroke:#aa3333,stroke-dasharray:3 3
    body["tx body"]:::body
    f0["UTXOW / ValueNotConservedUTxO"]:::ruleFail
    f0 --> body
    body:::bodyFail
    f1["UTXOW / MissingVKeyWitnesses"]:::ruleFail
    f1_s0["missing signer 8bd03209…b24fb1c1"]:::signerFail
    f1 --> f1_s0
    f1_s1["missing signer dea7197a…c5d2626d"]:::signerFail
    f1 --> f1_s1
    f1_s2["missing signer f3ab64b0…04d23e2e"]:::signerFail
    f1 --> f1_s2
```

