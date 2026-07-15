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

const errorMessage = (err) => (err instanceof Error ? err.message : String(err));

const PROVIDER_FAILURE_PREFIX = "provider-boundary|";

const isProviderBoundaryError = (err) =>
  errorMessage(err).startsWith(PROVIDER_FAILURE_PREFIX);

export const providerFailureGuidanceImpl = (selectedProvider) => (raw) => {
  const parts = String(raw).split("|");
  if (parts[0] !== "provider-boundary") {
    return `${selectedProvider} provider request failed: ${raw}`;
  }

  const provider = parts[1] || selectedProvider;
  const category = parts[2] || "response";
  const status = parts[3] || "";
  switch (category) {
    case "authentication":
      return `${provider} authentication failed (${status || "401"}). Check the project ID or bearer token in Settings and retry.`;
    case "permission":
      return `${provider} request was denied (${status || "403"}). Check credential permissions, the selected network, and Settings.`;
    case "rate-limit":
      return `${provider} rate limit reached (${status || "429"}). Wait and retry.`;
    case "provider":
      return `${provider} is unavailable (${status || "5xx"}). Retry later; the credential may still be valid.`;
    case "network":
      return `${provider} network request failed. Check connectivity and retry.`;
    case "cors":
      return provider === "Koios"
        ? "Koios request was blocked by CORS. A bearer token permits an attempt but does not guarantee browser access."
        : `${provider} request was blocked by CORS. A configured project ID permits an attempt but does not guarantee browser access.`;
    default:
      return `${provider} request failed${status ? ` (${status})` : ""}. Check Settings and retry.`;
  }
};

export const focusProviderErrorImpl = () => {
  const focus = () => {
    const alert = document.querySelector("[data-provider-error]");
    if (!(alert instanceof HTMLElement)) return false;
    alert.focus({ preventScroll: true });
    alert.scrollIntoView({ block: "center", inline: "nearest" });
    return true;
  };

  if (!focus()) requestAnimationFrame(focus);
};

const providerValidationContext = async (fetchValidationContext, errors) => {
  try {
    const raw = await fetchValidationContext();
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      errors.push("validation_context: provider returned a non-object response");
      return { fields: {}, source: "" };
    }
    const { source, ...fields } = parsed;
    return { fields, source: typeof source === "string" ? source : "" };
  } catch (err) {
    if (isProviderBoundaryError(err)) throw err;
    errors.push(`validation_context: ${errorMessage(err)}`);
    return { fields: {}, source: "" };
  }
};

export const resolveProducerTxContextImpl =
  (provider) => (source) => (inspectionResponse) => (fetchTxCbor) => (fetchValidationContext) => (fetchProducerTxs) => async () => {
    const { inputs, referenceInputs } = extractInspectionInputs(inspectionResponse);
    const requestedTxIds = [
      ...new Set([...inputs, ...referenceInputs].map((input) => input.tx_id)),
    ];
    const producerTxs = {};
    const missing = [];
    const errors = [];
    const validationContext = await providerValidationContext(fetchValidationContext, errors);

    if (!fetchProducerTxs && requestedTxIds.length > 0) {
      missing.push(...requestedTxIds);
      errors.push("producer_txs: provider credentials not supplied");
    } else {
      for (const txId of requestedTxIds) {
        try {
          const cbor = await fetchTxCbor(txId)();
          producerTxs[txId] = {
            tx_cbor: cbor,
            source,
          };
        } catch (err) {
          if (isProviderBoundaryError(err)) throw err;
          missing.push(txId);
          errors.push(`${txId}: ${errorMessage(err)}`);
        }
      }
    }

    return JSON.stringify({
      input_policy: "preserve",
      context: {
        ...validationContext.fields,
        producer_txs: producerTxs,
        resolution: {
          provider,
          source: "tx-cbor",
          validation_context_source: validationContext.source,
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
