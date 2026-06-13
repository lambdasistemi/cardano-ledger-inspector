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

const resolvedLabelsQuery = `
PREFIX cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX overlay: <https://lambdasistemi.github.io/cardano-ledger-inspector/overlay/amaru-treasury#>
SELECT ?label ?entity ?type ?scriptRole ?fromTxOutRef ?bech32 ?slug
WHERE {
  ?entity rdfs:label ?label .
  FILTER(
    STRSTARTS(STR(?entity), "https://lambdasistemi.github.io/cardano-ledger-inspector/overlay/amaru-treasury#")
    || STRSTARTS(STR(?entity), "urn:cardano:id:")
  )
  OPTIONAL { ?entity a ?type . }
  OPTIONAL { ?entity overlay:scriptRole ?scriptRole . }
  OPTIONAL { ?entity cardano:fromTxOutRef ?fromTxOutRef . }
  OPTIONAL { ?entity cardano:bech32 ?bech32 . }
  OPTIONAL { ?entity overlay:slug ?slug . }
}
ORDER BY ?label ?entity
`;

const typedFieldsQuery = `
SELECT ?subject ?field ?value
WHERE {
  ?subject ?predicate ?value .
  FILTER(STRSTARTS(STR(?predicate), "https://lambdasistemi.github.io/cardano-rdf/fixtures/tx-rdf#"))
  BIND(STRAFTER(STR(?predicate), "https://lambdasistemi.github.io/cardano-rdf/fixtures/tx-rdf#") AS ?field)
  FILTER(CONTAINS(STR(?field), "_"))
  FILTER(!REGEX(STR(?field), "^_[0-9]+_"))
}
ORDER BY ?subject ?field ?value
`;

const bindingValue = (binding) =>
  binding && binding.value !== undefined && binding.value !== null
    ? String(binding.value)
    : "";

const firstBindingValue = (...bindings) => {
  for (const binding of bindings) {
    const value = bindingValue(binding);
    if (value !== "") return value;
  }
  return "";
};

const localName = (value) => {
  const raw = String(value || "");
  const hashIndex = raw.lastIndexOf("#");
  if (hashIndex >= 0) return raw.slice(hashIndex + 1);
  const slashIndex = raw.lastIndexOf("/");
  if (slashIndex >= 0) return raw.slice(slashIndex + 1);
  const colonIndex = raw.lastIndexOf(":");
  if (colonIndex >= 0) return raw.slice(colonIndex + 1);
  return raw;
};

const humanToken = (value) => {
  const token = localName(value)
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .trim();
  if (token === "") return "Label";
  return token
    .split(/\s+/)
    .map((word) => word.slice(0, 1).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
};

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

const normalizeResolvedLabelRows = (result) => {
  if (!result || result.kind !== "solutions") {
    throw new Error("query did not return solution rows");
  }

  const bindings = result.json?.results?.bindings;
  if (!Array.isArray(bindings)) {
    throw new Error("query result missing bindings");
  }

  return bindings.map((binding) => ({
    label: bindingValue(binding.label),
    role: humanToken(firstBindingValue(binding.scriptRole, binding.type)),
    entity: bindingValue(binding.entity),
    matched: firstBindingValue(
      binding.fromTxOutRef,
      binding.bech32,
      binding.slug,
      binding.entity,
    ),
  }));
};

const normalizeTypedFieldRows = (result) => {
  if (!result || result.kind !== "solutions") {
    throw new Error("query did not return solution rows");
  }

  const bindings = result.json?.results?.bindings;
  if (!Array.isArray(bindings)) {
    throw new Error("query result missing bindings");
  }

  return bindings.map((binding) => ({
    subject: bindingValue(binding.subject),
    field: bindingValue(binding.field),
    value: bindingValue(binding.value),
  }));
};

export const queryImpl = (left) => (right) => (graphTtl) => (sparql) => () => {
  try {
    return right(globalThis.rdfShapes.query(graphTtl, sparql));
  } catch (err) {
    return left(errText(err));
  }
};

export const queryResolvedLabelsImpl = (left) => (right) => (graphTtl) => () => {
  try {
    const result = globalThis.rdfShapes.query(graphTtl, resolvedLabelsQuery);
    return right(normalizeResolvedLabelRows(result));
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

export const queryTypedFieldsImpl = (left) => (right) => (graphTtl) => () => {
  try {
    const result = globalThis.rdfShapes.query(graphTtl, typedFieldsQuery);
    return right(normalizeTypedFieldRows(result));
  } catch (err) {
    return left(errText(err));
  }
};
