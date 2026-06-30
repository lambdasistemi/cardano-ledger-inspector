#!/usr/bin/env python3
"""Generate 'meaningfully wrong' Conway txs by surgically mutating a real
valid fixture, so the inspector's Class-A / network SHACL shapes fire on a
genuinely decoded transaction (not a crafted graph). Single source of truth:
emits one .hex per example + a manifest the UI picker and the test both read."""
import sys, json, copy, cbor2, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1] / "specs/001-ledger-functional-layer/fixtures"
BASE = (ROOT / "conway-mainnet-tx.hex").read_text().strip()
OUT = ROOT / "broken"
base_tx = cbor2.loads(bytes.fromhex(BASE))

def enc(tx): return cbor2.dumps(tx).hex()

examples = []
def add(slug, label, severity, shape, desc, mutate):
    tx = cbor2.loads(bytes.fromhex(BASE))
    mutate(tx)
    hexs = enc(tx)
    (OUT / f"{slug}.hex").write_text(hexs + "\n")
    examples.append({"slug": slug, "label": label, "severity": severity,
                     "shape": shape, "description": desc, "bytes": len(hexs)//2})

def empty_inputs(tx): tx[0][0] = []
def ref_overlap(tx): tx[0][18] = list(tx[0][0])          # a reference input == a spent input
def network_mismatch(tx): tx[0][15] = 0                  # body says testnet; outputs are mainnet addrs
def aux_hash_unexpected(tx): tx[3] = None                # body has aux-hash (key 7) but no aux data
def aux_hash_missing(tx): del tx[0][7]                   # aux data present but body has no aux-hash

add("empty-inputs", "Empty input set", "violation", "InputSetEmptyUTxO",
    "Transaction spends nothing — the input set is empty.", empty_inputs)
add("reference-input-overlap", "Reference input overlaps a spent input", "violation",
    "ReferenceInputOverlapsWithInput",
    "A UTxO appears as both a spent input and a reference input.", ref_overlap)
add("network-mismatch", "Network id mismatch", "violation", "NetworkConsistency",
    "Body network id is testnet while the output addresses are mainnet.", network_mismatch)
add("aux-hash-unexpected", "Auxiliary-data hash without metadata", "violation",
    "AuxiliaryDataHashPresentButNotExpected",
    "Body carries an auxiliary-data hash but the transaction has no metadata.", aux_hash_unexpected)
add("aux-hash-missing", "Metadata without auxiliary-data hash", "violation",
    "AuxiliaryDataHashMissing",
    "Transaction has metadata but the body omits its auxiliary-data hash.", aux_hash_missing)

(OUT / "manifest.json").write_text(json.dumps(examples, indent=2) + "\n")
for e in examples:
    print(f"{e['slug']:26} {e['severity']:9} {e['shape']:38} {e['bytes']}B")
print("wrote", len(examples), "fixtures +manifest to", OUT)
