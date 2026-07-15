// Koios CBOR fetch. Returns a Promise<string> of the hex, or throws.
//
// Koios itself offers keyless access, but this browser workflow requires a
// bearer token as an explicit readiness gate before calling the adapter.
// Docs: https://api.koios.rest/

const BASES = {
  mainnet: "https://api.koios.rest/api/v1",
  preprod: "https://preprod.koios.rest/api/v1",
  preview: "https://preview.koios.rest/api/v1",
};

const koiosHeaders = (bearer) => {
  const headers = { "Content-Type": "application/json" };
  if (bearer && bearer.length > 0) {
    headers["Authorization"] = `Bearer ${bearer}`;
  }
  return headers;
};

const ledgerNetwork = (network) => (network === "mainnet" ? "mainnet" : "testnet");

const failureCategory = (status) => {
  if (status === 401) return "authentication";
  if (status === 403) return "permission";
  if (status === 429) return "rate-limit";
  if (status >= 500) return "provider";
  return "response";
};

const providerFailure = (category, status, detail) =>
  new Error(`provider-boundary|Koios|${category}|${status || ""}|${detail || ""}`);

const errorMessage = (err) => (err instanceof Error ? err.message : String(err));

const fetchWithBoundary = async (base, url, options) => {
  try {
    return await fetch(url, options);
  } catch (err) {
    let providerReachable = false;
    try {
      await fetch(base, { method: "GET", mode: "no-cors" });
      providerReachable = true;
    } catch (_) {
      // A failed same-provider probe is the observable network signal.
    }
    throw providerFailure(
      providerReachable ? "cors" : "network",
      "",
      errorMessage(err),
    );
  }
};

const readJson = async (resp, label) => {
  if (!resp.ok) {
    const body = await resp.text().catch(() => "");
    throw providerFailure(
      failureCategory(resp.status),
      String(resp.status),
      `${label}: ${body.slice(0, 200)}`,
    );
  }
  return resp.json();
};

const firstObject = (json, label) => {
  const value = Array.isArray(json) ? json[0] : json;
  if (!value || typeof value !== "object") {
    throw new Error(`Koios: ${label} response missing object payload`);
  }
  return value;
};

export const fetchTxCborImpl = (network) => (bearer) => (txHash) => async () => {
  const base = BASES[network] || BASES.mainnet;
  const headers = koiosHeaders(bearer);
  const resp = await fetchWithBoundary(base, `${base}/tx_cbor`, {
    method: "POST",
    headers,
    body: JSON.stringify({ _tx_hashes: [txHash] }),
  });
  // Koios returns CORS headers on preflight but NOT on the actual POST
  // response, which browsers reject. The fetch above typically rejects as
  // TypeError("Failed to fetch") before we get here — the wrapping in
  // Main.purs surfaces that to the user. This .ok check only runs if the
  // browser accepted the response (e.g. running from a same-origin proxy).
  const arr = await readJson(resp, "tx cbor");
  if (!Array.isArray(arr) || arr.length === 0) {
    throw new Error("Koios: tx hash not found");
  }
  const entry = arr[0];
  if (!entry.cbor) {
    throw new Error(`Koios: response missing 'cbor' field: ${JSON.stringify(entry).slice(0, 200)}`);
  }
  return entry.cbor;
};

export const fetchValidationContextImpl = (network) => (bearer) => async () => {
  const base = BASES[network] || BASES.mainnet;
  const headers = koiosHeaders(bearer);
  const [tipResponse, pparamsResponse] = await Promise.all([
    fetchWithBoundary(base, `${base}/tip`, { headers }).then((resp) =>
      readJson(resp, "tip")
    ),
    fetchWithBoundary(base, `${base}/cli_protocol_params`, { headers }).then(
      (resp) => readJson(resp, "protocol parameters"),
    ),
  ]);
  const tip = firstObject(tipResponse, "tip");
  const protocolParameters = firstObject(pparamsResponse, "protocol parameters");

  return JSON.stringify({
    network: ledgerNetwork(network),
    slot: String(tip.abs_slot),
    epoch: String(tip.epoch_no),
    protocol_parameters: protocolParameters,
    source: "koios.tip+cli_protocol_params",
  });
};
