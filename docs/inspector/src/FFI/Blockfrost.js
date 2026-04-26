// Blockfrost CBOR fetch. Returns a Promise<string> of the hex, or throws.
// Project ID goes in the header (not URL) to avoid leaking via Referer/logs.

const BASES = {
  mainnet: "https://cardano-mainnet.blockfrost.io/api/v0",
  preprod: "https://cardano-preprod.blockfrost.io/api/v0",
  preview: "https://cardano-preview.blockfrost.io/api/v0",
};

export const fetchTxCborImpl = (network) => (projectId) => (txHash) => async () => {
  return fetchTxCborRaw(network, projectId, txHash);
};

const fetchTxCborRaw = async (network, projectId, txHash) => {
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
    const { inputs, referenceInputs } = extractInspectionInputs(inspectionResponse);
    const requestedTxIds = [
      ...new Set([...inputs, ...referenceInputs].map((input) => input.tx_id)),
    ];
    const producerTxs = {};
    const missing = [];
    const errors = [];

    for (const txId of requestedTxIds) {
      try {
        const cbor = await fetchTxCborRaw(network, projectId, txId);
        producerTxs[txId] = {
          tx_cbor: cbor,
          source: "blockfrost.txs.cbor",
        };
      } catch (err) {
        missing.push(txId);
        errors.push(`${txId}: ${err instanceof Error ? err.message : String(err)}`);
      }
    }

    return JSON.stringify({
      input_policy: "preserve",
      context: {
        producer_txs: producerTxs,
        resolution: {
          provider: "blockfrost",
          source: "tx-cbor",
          requested_input_count: inputs.length,
          requested_reference_input_count: referenceInputs.length,
          requested_tx_count: requestedTxIds.length,
          resolved_count: Object.keys(producerTxs).length,
          missing,
          errors,
          unspent_status: "not_checked",
        },
      },
    });
  };
