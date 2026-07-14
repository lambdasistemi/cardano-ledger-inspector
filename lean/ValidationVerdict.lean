inductive LedgerStatus where
  | valid
  | invalid
  | incomplete
  | rejected
  deriving DecidableEq, Repr

inductive ShaclStatus where
  | pass
  | fail
  | error
  deriving DecidableEq, Repr

inductive Tone where
  | green
  | amber
  | red
  deriving DecidableEq, Repr

def ledgerTone : LedgerStatus -> Bool -> Bool -> Tone
  | .valid, true, true => .green
  | .valid, _, _ => .amber
  | .invalid, _, _ => .red
  | .incomplete, _, _ => .amber
  | .rejected, _, _ => .red

def shaclTone : ShaclStatus -> Tone
  | .pass => .green
  | .fail => .red
  | .error => .red

def normalizedLedgerTone
    (ledger : LedgerStatus)
    (complete validForSuppliedContext : Bool)
    (_shacl : ShaclStatus) : Tone :=
  ledgerTone ledger complete validForSuppliedContext

theorem green_precondition
    {ledger : LedgerStatus}
    {complete validForSuppliedContext : Bool}
    (h : ledgerTone ledger complete validForSuppliedContext = .green) :
    ledger = .valid ∧ complete = true ∧ validForSuppliedContext = true := by
  cases ledger <;> cases complete <;> cases validForSuppliedContext <;> simp [ledgerTone] at h ⊢

theorem ledger_tone_independent_of_shacl
    (ledger : LedgerStatus)
    (complete validForSuppliedContext : Bool)
    (left right : ShaclStatus) :
    normalizedLedgerTone ledger complete validForSuppliedContext left =
      normalizedLedgerTone ledger complete validForSuppliedContext right := rfl
