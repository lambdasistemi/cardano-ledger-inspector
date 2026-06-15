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

const decodedTreeRootQuery = `
PREFIX cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?transaction ?txId ?txIdHex ?valid ?resolvedLabel ?resolvedType
WHERE {
  ?transaction a cardano:Transaction ;
    cardano:hasTxId ?txId .
  OPTIONAL { ?txId cardano:bytesHex ?txIdHex . }
  OPTIONAL { ?transaction cardano:isValid ?valid . }
  OPTIONAL { ?transaction rdfs:label ?resolvedLabel . }
  OPTIONAL { ?transaction a ?resolvedType . }
}
ORDER BY ?transaction
LIMIT 1
`;

const decodedBodyFieldsQuery = `
PREFIX cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?label ?kind ?entity ?value ?raw ?sort ?resolvedLabel ?resolvedType
WHERE {
  ?transaction a cardano:Transaction .
  {
    ?transaction cardano:isValid ?value .
    BIND(?transaction AS ?entity)
    BIND("Validity" AS ?label)
    BIND("boolean" AS ?kind)
    BIND("10" AS ?sort)
  } UNION {
    ?transaction cardano:hasFee ?value .
    BIND(?transaction AS ?entity)
    BIND("Fee" AS ?label)
    BIND("lovelace" AS ?kind)
    BIND("20" AS ?sort)
  } UNION {
    ?transaction cardano:scriptDataHash ?entity .
    OPTIONAL { ?entity cardano:bytesHex ?raw . }
    BIND("Script data hash" AS ?label)
    BIND("hash" AS ?kind)
    BIND(STR(?entity) AS ?value)
    BIND("30" AS ?sort)
  } UNION {
    ?transaction cardano:auxiliaryDataHash ?entity .
    OPTIONAL { ?entity cardano:bytesHex ?raw . }
    BIND("Auxiliary data hash" AS ?label)
    BIND("hash" AS ?kind)
    BIND(STR(?entity) AS ?value)
    BIND("40" AS ?sort)
  } UNION {
    ?transaction cardano:totalCollateral ?value .
    BIND(?transaction AS ?entity)
    BIND("Total collateral" AS ?label)
    BIND("lovelace" AS ?kind)
    BIND("50" AS ?sort)
  } UNION {
    ?transaction cardano:hasMint ?entity .
    BIND("Mint" AS ?label)
    BIND("mint" AS ?kind)
    BIND(STR(?entity) AS ?value)
    BIND("60" AS ?sort)
  } UNION {
    ?transaction cardano:hasCollateralReturn ?entity .
    BIND("Collateral return" AS ?label)
    BIND("output" AS ?kind)
    BIND(STR(?entity) AS ?value)
    BIND("70" AS ?sort)
  }
  OPTIONAL { ?entity rdfs:label ?resolvedLabel . }
  OPTIONAL { ?entity a ?resolvedType . }
}
ORDER BY ?sort ?label ?value ?entity
`;

const decodedInputsQuery = `
PREFIX cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?section ?entity ?txIdHex ?index ?sort ?resolvedLabel ?resolvedType
WHERE {
  ?transaction a cardano:Transaction .
  {
    ?transaction cardano:hasInput ?entity .
    BIND("Inputs" AS ?section)
    BIND("10" AS ?sort)
  } UNION {
    ?transaction cardano:hasReferenceInput ?entity .
    BIND("Reference inputs" AS ?section)
    BIND("20" AS ?sort)
  } UNION {
    ?transaction cardano:hasCollateralInput ?entity .
    BIND("Collateral inputs" AS ?section)
    BIND("30" AS ?sort)
  }
  OPTIONAL {
    ?entity cardano:fromTxOutRef ?ref .
    OPTIONAL { ?ref cardano:hasIndex ?index . }
    OPTIONAL {
      ?ref cardano:hasTxId ?txId .
      OPTIONAL { ?txId cardano:bytesHex ?txIdHex . }
    }
  }
  OPTIONAL { ?entity rdfs:label ?resolvedLabel . }
  OPTIONAL { ?entity a ?resolvedType . }
}
ORDER BY ?sort ?txIdHex ?index ?entity
`;

const decodedOutputsQuery = `
PREFIX cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?output ?index ?address ?lovelace ?datum ?datumRaw ?datumHash ?datumHashHex ?resolvedLabel ?resolvedType
WHERE {
  ?transaction a cardano:Transaction ;
    cardano:hasOutput ?output .
  OPTIONAL { ?output cardano:hasIndex ?index . }
  OPTIONAL { ?output cardano:atAddress ?address . }
  OPTIONAL { ?output cardano:lovelace ?lovelace . }
  OPTIONAL {
    ?output cardano:hasDatum ?datum .
    OPTIONAL { ?datum cardano:hasRawBytes ?datumRaw . }
    OPTIONAL {
      ?datum cardano:hasHash ?datumHash .
      OPTIONAL { ?datumHash cardano:bytesHex ?datumHashHex . }
    }
  }
  OPTIONAL { ?output rdfs:label ?resolvedLabel . }
  OPTIONAL { ?output a ?resolvedType . }
}
ORDER BY ?index ?output
`;

const decodedWitnessesQuery = `
PREFIX cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?witness ?verificationKey ?verificationKeyHex ?signature ?resolvedLabel ?resolvedType
WHERE {
  ?transaction a cardano:Transaction ;
    cardano:hasKeyWitness ?witness .
  OPTIONAL {
    ?witness cardano:hasVerificationKey ?verificationKey .
    OPTIONAL { ?verificationKey cardano:bytesHex ?verificationKeyHex . }
  }
  OPTIONAL { ?witness cardano:hasSignature ?signature . }
  OPTIONAL { ?witness rdfs:label ?resolvedLabel . }
  OPTIONAL { ?witness a ?resolvedType . }
}
ORDER BY ?verificationKeyHex ?witness
`;

const decodedRedeemersQuery = `
PREFIX cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?redeemer ?purpose ?index ?data ?dataRaw ?dataHash ?dataHashHex ?memory ?cpu ?resolvedLabel ?resolvedType
WHERE {
  ?transaction a cardano:Transaction ;
    cardano:hasRedeemer ?redeemer .
  OPTIONAL { ?redeemer cardano:hasPurpose ?purpose . }
  OPTIONAL { ?redeemer cardano:hasIndex ?index . }
  OPTIONAL {
    ?redeemer cardano:hasData ?data .
    OPTIONAL { ?data cardano:hasRawBytes ?dataRaw . }
    OPTIONAL {
      ?data cardano:hasHash ?dataHash .
      OPTIONAL { ?dataHash cardano:bytesHex ?dataHashHex . }
    }
  }
  OPTIONAL {
    ?redeemer cardano:hasExUnits ?exUnits .
    OPTIONAL { ?exUnits cardano:memoryUnits ?memory . }
    OPTIONAL { ?exUnits cardano:cpuUnits ?cpu . }
  }
  OPTIONAL { ?redeemer rdfs:label ?resolvedLabel . }
  OPTIONAL { ?redeemer a ?resolvedType . }
}
ORDER BY ?purpose ?index ?redeemer
`;

const decodedMetadataQuery = `
PREFIX cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?metadata ?label ?raw ?text ?resolvedLabel ?resolvedType
WHERE {
  ?transaction a cardano:Transaction ;
    cardano:hasAuxiliaryData ?auxiliaryData .
  OPTIONAL { ?auxiliaryData cardano:hasRawBytes ?raw . }
  ?auxiliaryData cardano:hasMetadatum ?metadata .
  OPTIONAL { ?metadata cardano:metadataLabel ?label . }
  OPTIONAL { ?metadata cardano:metadatumValue ?value . }
  OPTIONAL { ?value cardano:hasElement ?element . }
  OPTIONAL { ?element cardano:metadatumValue ?elementValue . }
  OPTIONAL { ?elementValue cardano:textValue ?text . }
  OPTIONAL { ?metadata rdfs:label ?resolvedLabel . }
  OPTIONAL { ?metadata a ?resolvedType . }
}
ORDER BY ?label ?metadata ?text
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

const queryBindings = (graphTtl, sparql) => {
  const result = globalThis.rdfShapes.query(graphTtl, sparql);
  if (!result || result.kind !== "solutions") {
    throw new Error("query did not return solution rows");
  }

  const bindings = result.json?.results?.bindings;
  if (!Array.isArray(bindings)) {
    throw new Error("query result missing bindings");
  }
  return bindings;
};

const compact = (value, max = 72) => {
  const raw = String(value || "");
  return raw.length > max ? `${raw.slice(0, max - 1)}...` : raw;
};

const slug = (value) =>
  String(value || "row")
    .replace(/[^A-Za-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 96) || "row";

const treeRow = ({
  id,
  parentId = "",
  depth = 0,
  order = 0,
  label,
  kind = "",
  value = "",
  summary = "",
  raw = "",
  resolvedLabel = "",
  resolvedType = "",
}) => ({
  id,
  parentId,
  depth,
  order,
  label,
  kind,
  value,
  summary,
  raw,
  resolvedLabel,
  resolvedType,
});

const addSection = (rows, id, label, order, summary = "") => {
  rows.push(
    treeRow({
      id,
      parentId: "decoded-root",
      depth: 1,
      order,
      label,
      kind: "section",
      summary,
    }),
  );
};

const appendLeaf = (rows, parentId, depth, order, label, kind, value, extra = {}) => {
  const stringValue = String(value || "");
  if (stringValue === "") return;
  rows.push(
    treeRow({
      id: `${parentId}-${slug(label)}-${slug(stringValue)}-${order}`,
      parentId,
      depth,
      order,
      label,
      kind,
      value: stringValue,
      summary: compact(stringValue),
      raw: extra.raw || stringValue,
      resolvedLabel: extra.resolvedLabel || "",
      resolvedType: extra.resolvedType || "",
    }),
  );
};

const countText = (count, noun) => `${count} ${noun}${count === 1 ? "" : "s"}`;

const normalizeDecodedTreeRows = (graphTtl) => {
  const roots = queryBindings(graphTtl, decodedTreeRootQuery);
  if (roots.length === 0) return [];

  const root = roots[0];
  const txId = firstBindingValue(root.txIdHex, root.txId, root.transaction);
  const transactionId = bindingValue(root.transaction);
  const rows = [
    treeRow({
      id: "decoded-root",
      depth: 0,
      order: 0,
      label: "Transaction",
      kind: humanToken(firstBindingValue(root.resolvedType) || "Transaction"),
      value: transactionId,
      summary: compact(transactionId),
      raw: txId,
      resolvedLabel: bindingValue(root.resolvedLabel),
      resolvedType: bindingValue(root.resolvedType),
    }),
  ];

  const bodyFields = queryBindings(graphTtl, decodedBodyFieldsQuery);
  const inputs = queryBindings(graphTtl, decodedInputsQuery);
  const outputs = queryBindings(graphTtl, decodedOutputsQuery);
  const witnesses = queryBindings(graphTtl, decodedWitnessesQuery);
  const redeemers = queryBindings(graphTtl, decodedRedeemersQuery);
  const metadata = queryBindings(graphTtl, decodedMetadataQuery);

  if (bodyFields.length > 0) {
    addSection(rows, "decoded-body", "Body", 10, countText(bodyFields.length, "field"));
    bodyFields.forEach((field, index) => {
      appendLeaf(
        rows,
        "decoded-body",
        2,
        index,
        bindingValue(field.label),
        bindingValue(field.kind),
        firstBindingValue(field.raw, field.value, field.entity),
        {
          raw: firstBindingValue(field.raw, field.value, field.entity),
          resolvedLabel: bindingValue(field.resolvedLabel),
          resolvedType: bindingValue(field.resolvedType),
        },
      );
    });
  }

  if (inputs.length > 0) {
    addSection(rows, "decoded-inputs", "Inputs", 20, countText(inputs.length, "input"));
    inputs.forEach((input, index) => {
      const section = bindingValue(input.section);
      const tx = bindingValue(input.txIdHex);
      const inputIndex = bindingValue(input.index);
      const value =
        tx === "" && inputIndex === ""
          ? bindingValue(input.entity)
          : `${compact(tx, 28)}#${inputIndex}`;
      appendLeaf(
        rows,
        "decoded-inputs",
        2,
        index,
        section === "Inputs" ? `Input ${index}` : `${section} ${index}`,
        "tx-out-ref",
        value,
        {
          raw: tx === "" ? bindingValue(input.entity) : `${tx}#${inputIndex}`,
          resolvedLabel: bindingValue(input.resolvedLabel),
          resolvedType: bindingValue(input.resolvedType),
        },
      );
    });
  }

  if (outputs.length > 0) {
    addSection(rows, "decoded-outputs", "Outputs", 30, countText(outputs.length, "output"));
    outputs.forEach((output, index) => {
      const outputIndex = firstBindingValue(output.index, { value: String(index) });
      const outputId = `decoded-output-${slug(outputIndex)}-${index}`;
      rows.push(
        treeRow({
          id: outputId,
          parentId: "decoded-outputs",
          depth: 2,
          order: index,
          label: `Output ${outputIndex}`,
          kind: "output",
          value: bindingValue(output.output),
          summary: compact(bindingValue(output.output)),
          raw: bindingValue(output.output),
          resolvedLabel: bindingValue(output.resolvedLabel),
          resolvedType: bindingValue(output.resolvedType),
        }),
      );
      appendLeaf(rows, outputId, 3, 10, "Index", "integer", outputIndex);
      appendLeaf(rows, outputId, 3, 20, "Lovelace", "lovelace", bindingValue(output.lovelace));
      appendLeaf(rows, outputId, 3, 30, "Address", "address", bindingValue(output.address));
      appendLeaf(rows, outputId, 3, 40, "Datum hash", "hash", firstBindingValue(output.datumHashHex, output.datumHash));
      appendLeaf(rows, outputId, 3, 50, "Datum raw bytes", "raw-bytes", bindingValue(output.datumRaw));
    });
  }

  const feeFields = bodyFields.filter((field) => bindingValue(field.label) === "Fee");
  if (feeFields.length > 0) {
    addSection(rows, "decoded-fee", "Fee", 40, compact(bindingValue(feeFields[0].value)));
    feeFields.forEach((field, index) => {
      appendLeaf(rows, "decoded-fee", 2, index, "Lovelace", "lovelace", bindingValue(field.value));
    });
  }

  if (witnesses.length > 0) {
    addSection(rows, "decoded-witnesses", "Witnesses", 50, countText(witnesses.length, "key witness"));
    witnesses.forEach((witness, index) => {
      const witnessId = `decoded-key-witness-${index}`;
      rows.push(
        treeRow({
          id: witnessId,
          parentId: "decoded-witnesses",
          depth: 2,
          order: index,
          label: `Key witness ${index}`,
          kind: "key-witness",
          value: firstBindingValue(witness.verificationKeyHex, witness.verificationKey, witness.witness),
          summary: compact(firstBindingValue(witness.verificationKeyHex, witness.verificationKey, witness.witness)),
          raw: bindingValue(witness.witness),
          resolvedLabel: bindingValue(witness.resolvedLabel),
          resolvedType: bindingValue(witness.resolvedType),
        }),
      );
      appendLeaf(rows, witnessId, 3, 10, "Verification key", "key", firstBindingValue(witness.verificationKeyHex, witness.verificationKey));
      appendLeaf(rows, witnessId, 3, 20, "Signature", "signature", bindingValue(witness.signature));
    });
  }

  if (redeemers.length > 0) {
    addSection(rows, "decoded-redeemers", "Redeemers", 60, countText(redeemers.length, "redeemer"));
    redeemers.forEach((redeemer, index) => {
      const redeemerId = `decoded-redeemer-${index}`;
      const purpose = bindingValue(redeemer.purpose);
      const redeemerIndex = bindingValue(redeemer.index);
      rows.push(
        treeRow({
          id: redeemerId,
          parentId: "decoded-redeemers",
          depth: 2,
          order: index,
          label: purpose === "" ? `Redeemer ${index}` : `${purpose} redeemer ${redeemerIndex}`,
          kind: "redeemer",
          value: bindingValue(redeemer.redeemer),
          summary: compact(firstBindingValue(redeemer.dataHashHex, redeemer.dataHash, redeemer.redeemer)),
          raw: bindingValue(redeemer.redeemer),
          resolvedLabel: bindingValue(redeemer.resolvedLabel),
          resolvedType: bindingValue(redeemer.resolvedType),
        }),
      );
      appendLeaf(rows, redeemerId, 3, 10, "Purpose", "purpose", purpose);
      appendLeaf(rows, redeemerId, 3, 20, "Index", "integer", redeemerIndex);
      appendLeaf(rows, redeemerId, 3, 30, "Data hash", "hash", firstBindingValue(redeemer.dataHashHex, redeemer.dataHash));
      appendLeaf(rows, redeemerId, 3, 40, "Data raw bytes", "raw-bytes", bindingValue(redeemer.dataRaw));
      appendLeaf(rows, redeemerId, 3, 50, "Memory units", "ex-units", bindingValue(redeemer.memory));
      appendLeaf(rows, redeemerId, 3, 60, "CPU units", "ex-units", bindingValue(redeemer.cpu));
    });
  }

  const metadataById = new Map();
  for (const row of metadata) {
    const id = bindingValue(row.metadata);
    if (id !== "" && !metadataById.has(id)) metadataById.set(id, row);
  }
  const metadataRows = Array.from(metadataById.values());
  if (metadataRows.length > 0) {
    addSection(rows, "decoded-metadata", "Metadata", 70, countText(metadataRows.length, "label"));
    metadataRows.forEach((meta, index) => {
      const metaId = `decoded-metadata-${slug(bindingValue(meta.label))}-${index}`;
      rows.push(
        treeRow({
          id: metaId,
          parentId: "decoded-metadata",
          depth: 2,
          order: index,
          label: `Metadata label ${bindingValue(meta.label)}`,
          kind: "metadata",
          value: bindingValue(meta.metadata),
          summary: compact(firstBindingValue(meta.text, meta.raw, meta.metadata)),
          raw: firstBindingValue(meta.raw, meta.metadata),
          resolvedLabel: bindingValue(meta.resolvedLabel),
          resolvedType: bindingValue(meta.resolvedType),
        }),
      );
      appendLeaf(rows, metaId, 3, 10, "Metadata label", "integer", bindingValue(meta.label));
      appendLeaf(rows, metaId, 3, 20, "Text", "text", bindingValue(meta.text));
      appendLeaf(rows, metaId, 3, 30, "Raw bytes", "raw-bytes", bindingValue(meta.raw));
    });
  }

  return rows.sort((a, b) => {
    if (a.parentId !== b.parentId) return a.parentId.localeCompare(b.parentId);
    if (a.order !== b.order) return a.order - b.order;
    return a.label.localeCompare(b.label);
  });
};

const reportText = (value) =>
  value === null || value === undefined ? "" : String(value);

const shapeMetadataByPath = (shapesTtl) => {
  const query = `
PREFIX sh: <http://www.w3.org/ns/shacl#>
SELECT ?sourceShape ?path ?message
WHERE {
  ?sourceShape sh:path ?path .
  OPTIONAL { ?sourceShape sh:message ?message . }
}
`;
  const metadata = new Map();

  try {
    const result = globalThis.rdfShapes.query(shapesTtl, query);
    const bindings = result?.json?.results?.bindings;
    if (!Array.isArray(bindings)) return metadata;

    for (const binding of bindings) {
      const path = bindingValue(binding.path);
      if (path === "" || metadata.has(path)) continue;
      metadata.set(path, {
        sourceShape: bindingValue(binding.sourceShape),
        message: bindingValue(binding.message),
      });
    }
  } catch (_) {
    return metadata;
  }

  return metadata;
};

const normalizeViolation = (violation, shapeMetadata) => {
  const path = reportText(violation?.path);
  const metadata = shapeMetadata.get(path) || {};
  const sourceShape =
    reportText(violation?.source_shape ?? violation?.sourceShape) ||
    metadata.sourceShape ||
    "";
  const message = metadata.message || reportText(violation?.message);

  return {
    focusNode: reportText(violation?.focus_node),
    path,
    value: reportText(violation?.value),
    sourceShape,
    sourceConstraintComponent: reportText(violation?.source_constraint_component),
    message,
    severity: reportText(violation?.severity),
  };
};

const normalizeValidationReport = (result, shapesTtl) => {
  if (!result || typeof result !== "object") {
    throw new Error("validate did not return an object");
  }
  if (typeof result.conforms !== "boolean") {
    throw new Error("validate result missing conforms boolean");
  }

  const shapeMetadata = shapeMetadataByPath(shapesTtl);

  return {
    conforms: result.conforms,
    violations: Array.isArray(result.violations)
      ? result.violations.map((violation) =>
          normalizeViolation(violation, shapeMetadata),
        )
      : [],
  };
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

export const queryDecodedTreeImpl = (left) => (right) => (graphTtl) => () => {
  try {
    return right(normalizeDecodedTreeRows(graphTtl));
  } catch (err) {
    return left(errText(err));
  }
};

export const validateImpl = (left) => (right) => (dataTtl) => (shapesTtl) => () => {
  try {
    return right(
      normalizeValidationReport(
        globalThis.rdfShapes.validate(dataTtl, shapesTtl),
        shapesTtl,
      ),
    );
  } catch (err) {
    return left(errText(err));
  }
};
