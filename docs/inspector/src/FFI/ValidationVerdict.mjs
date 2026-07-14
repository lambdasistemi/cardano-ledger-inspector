const knownLedgerStatus = new Set(["valid", "invalid", "incomplete", "rejected"]);

const normalizedLedgerStatus = (status) =>
  knownLedgerStatus.has(status) ? status : "rejected";

const nullableBoolean = (value) =>
  value === true ? true : value === false ? false : null;

export const ledgerVerdict = ({ status, complete, validForSuppliedContext }) => {
  const canonicalStatus = normalizedLedgerStatus(status);
  const evidence = {
    status: canonicalStatus,
    complete: complete === true,
    validForSuppliedContext: nullableBoolean(validForSuppliedContext),
  };

  if (
    evidence.status === "valid" &&
    evidence.complete &&
    evidence.validForSuppliedContext
  ) {
    return {
      ...evidence,
      tone: "green",
      title: "Ledger validation passed",
      detail: "Complete validation accepted the transaction for the supplied context.",
    };
  }

  switch (evidence.status) {
    case "valid":
      return {
        ...evidence,
        tone: "amber",
        title: "Ledger validation evidence is incomplete",
        detail: "A valid status without complete supplied-context evidence is not a pass.",
      };
    case "invalid":
      return {
        ...evidence,
        tone: "red",
        title: "Ledger validation failed",
        detail: "The ledger rejected the transaction as invalid for the supplied context.",
      };
    case "incomplete":
      return {
        ...evidence,
        tone: "amber",
        title: "Ledger validation is incomplete",
        detail: "More context is required before a final ledger verdict is available.",
      };
    default:
      return {
        ...evidence,
        tone: "red",
        title: "Ledger validation was rejected",
        detail: "The supplied validation context could not be evaluated.",
      };
  }
};

export const shaclVerdict = (state) => {
  switch (state) {
    case "pass":
      return {
        state,
        tone: "green",
        title: "SHACL conformance passed",
        detail: "The RDF graph conforms to the selected SHACL shapes.",
      };
    case "fail":
      return {
        state,
        tone: "red",
        title: "SHACL conformance failed",
        detail: "The RDF graph has SHACL conformance findings.",
      };
    default:
      return {
        state: "error",
        tone: "red",
        title: "SHACL conformance could not be evaluated",
        detail: "SHACL evaluation returned an error.",
      };
  }
};
