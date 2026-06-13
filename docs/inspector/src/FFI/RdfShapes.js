// Thin wrapper over globalThis.rdfShapes.query, seeded by src/bootstrap.js.
// The vendored engine returns a plain JS object on success and throws on
// Turtle/SPARQL errors; surface that as Either String Json for PureScript.

const errText = (err) =>
  err && err.message ? String(err.message) : String(err);

const transactionOutputsQuery = `
PREFIX cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#>
SELECT ?transaction ?txId (COUNT(?output) AS ?outputs)
WHERE {
  ?transaction a cardano:Transaction ;
    cardano:hasTxId ?txId .
  OPTIONAL { ?transaction cardano:hasOutput ?output . }
}
GROUP BY ?transaction ?txId
ORDER BY ?transaction
`;

const bindingValue = (binding) =>
  binding && binding.value !== undefined && binding.value !== null
    ? String(binding.value)
    : "";

const normalizeTransactionOutputRows = (result) => {
  if (!result || result.kind !== "solutions") {
    throw new Error("query did not return solution rows");
  }

  const bindings = result.json?.results?.bindings;
  if (!Array.isArray(bindings)) {
    throw new Error("query result missing bindings");
  }

  return bindings.map((binding) => ({
    transaction: bindingValue(binding.transaction),
    txId: bindingValue(binding.txId),
    outputs: bindingValue(binding.outputs),
  }));
};

export const queryImpl = (left) => (right) => (graphTtl) => (sparql) => () => {
  try {
    return right(globalThis.rdfShapes.query(graphTtl, sparql));
  } catch (err) {
    return left(errText(err));
  }
};

export const queryTransactionOutputsImpl = (left) => (right) => (graphTtl) => () => {
  try {
    const result = globalThis.rdfShapes.query(graphTtl, transactionOutputsQuery);
    return right(normalizeTransactionOutputRows(result));
  } catch (err) {
    return left(errText(err));
  }
};
