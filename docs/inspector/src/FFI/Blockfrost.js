// Blockfrost CBOR fetch. Returns a Promise<string> of the hex, or throws.
// Project ID goes in the header (not URL) to avoid leaking via Referer/logs.

const BASES = {
  mainnet: "https://cardano-mainnet.blockfrost.io/api/v0",
  preprod: "https://cardano-preprod.blockfrost.io/api/v0",
  preview: "https://cardano-preview.blockfrost.io/api/v0",
};

export const fetchTxCborImpl = (network) => (projectId) => (txHash) => async () => {
  const base = BASES[network] || BASES.mainnet;
  const resp = await fetch(`${base}/txs/${txHash}/cbor`, {
    headers: { project_id: projectId },
  });
  if (!resp.ok) {
    const body = await resp.text().catch(() => "");
    throw new Error(`Blockfrost ${resp.status}: ${body.slice(0, 200)}`);
  }
  const json = await resp.json();
  return json.cbor;
};

const operationResult = (parsed) => parsed?.result ?? parsed;

const inputKey = (input) => `${input.tx_id}#${input.index}`;

const isTxIn = (input) =>
  input &&
  typeof input === "object" &&
  /^[0-9a-fA-F]{64}$/.test(String(input.tx_id || "")) &&
  Number.isInteger(Number(input.index));

const uniqueTxIns = (inputs) => {
  const seen = new Set();
  const txIns = [];
  for (const input of inputs.filter(isTxIn)) {
    const txIn = {
      tx_id: String(input.tx_id).toLowerCase(),
      index: Number(input.index),
    };
    const key = inputKey(txIn);
    if (seen.has(key)) continue;
    seen.add(key);
    txIns.push({ ...txIn, key });
  }
  return txIns;
};

const lovelaceOf = (amount) => {
  const lovelace = Array.isArray(amount)
    ? amount.find((entry) => entry && entry.unit === "lovelace")
    : null;
  return lovelace ? String(lovelace.quantity ?? "") : "";
};

const assetsOf = (amount) => {
  const assets = {};
  if (!Array.isArray(amount)) return assets;
  for (const entry of amount) {
    if (!entry || entry.unit === "lovelace") continue;
    assets[String(entry.unit)] = String(entry.quantity ?? "");
  }
  return assets;
};

const normalizeOutput = (txIn, output) => ({
  tx_id: txIn.tx_id,
  index: txIn.index,
  address: String(output?.address ?? ""),
  lovelace: lovelaceOf(output?.amount),
  assets: assetsOf(output?.amount),
  datum_hash: output?.data_hash ? String(output.data_hash) : null,
  inline_datum_cbor: output?.inline_datum ? String(output.inline_datum).replace(/^0x/, "") : null,
  reference_script_hash: output?.reference_script_hash
    ? String(output.reference_script_hash)
    : null,
  source: "blockfrost.txs.utxos.outputs",
  unspent_status: "not_checked",
});

const extractInspectionInputs = (inspectionResponse) => {
  const parsed = JSON.parse(inspectionResponse);
  const inspection = operationResult(parsed)?.inspection ?? operationResult(parsed);
  const inputs = Array.isArray(inspection?.inputs) ? inspection.inputs : [];
  const referenceInputs = Array.isArray(inspection?.reference_inputs)
    ? inspection.reference_inputs
    : [];
  return {
    inputs: uniqueTxIns(inputs),
    referenceInputs: uniqueTxIns(referenceInputs),
  };
};

export const resolveInputContextImpl =
  (network) => (projectId) => (inspectionResponse) => async () => {
    const base = BASES[network] || BASES.mainnet;
    const { inputs, referenceInputs } = extractInspectionInputs(inspectionResponse);
    const requested = uniqueTxIns([...inputs, ...referenceInputs]);
    const utxo = {};
    const missing = [];
    const errors = [];
    const byTx = new Map();

    for (const txIn of requested) {
      if (!byTx.has(txIn.tx_id)) byTx.set(txIn.tx_id, []);
      byTx.get(txIn.tx_id).push(txIn);
    }

    for (const [txId, txIns] of byTx.entries()) {
      let json;
      try {
        const resp = await fetch(`${base}/txs/${txId}/utxos`, {
          headers: { project_id: projectId },
        });
        if (!resp.ok) {
          const body = await resp.text().catch(() => "");
          throw new Error(`Blockfrost ${resp.status}: ${body.slice(0, 200)}`);
        }
        json = await resp.json();
      } catch (err) {
        for (const txIn of txIns) missing.push(txIn.key);
        errors.push(`${txId}: ${err instanceof Error ? err.message : String(err)}`);
        continue;
      }

      const outputs = Array.isArray(json?.outputs) ? json.outputs : [];
      for (const txIn of txIns) {
        const output = outputs.find(
          (candidate) => Number(candidate?.output_index) === txIn.index,
        );
        if (!output) {
          missing.push(txIn.key);
          continue;
        }
        utxo[txIn.key] = normalizeOutput(txIn, output);
      }
    }

    return JSON.stringify({
      input_policy: "preserve",
      context: {
        utxo,
        resolution: {
          provider: "blockfrost",
          source: "tx-input-producer-outputs",
          requested_input_count: inputs.length,
          requested_reference_input_count: referenceInputs.length,
          resolved_count: Object.keys(utxo).length,
          missing,
          errors,
          unspent_status: "not_checked",
        },
      },
    });
  };
