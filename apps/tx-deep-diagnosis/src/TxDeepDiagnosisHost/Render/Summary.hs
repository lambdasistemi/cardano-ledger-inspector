{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Summary
Description : Top-level summary.md tying the cuts together with prose.

Sections, in fixed order so the file diffs cleanly and the first
screen stays reader-first:

* Title / tx id
* Headline action summary
* Verdict
* Validation failures
* Balance
* Fees & resources
* Observations / claims / effects
* Smart-contract calls / withdrawals / outputs / datums
* Warnings
* Diagrams
-}
module TxDeepDiagnosisHost.Render.Summary (
    EmittedFiles (..),
    noEmittedFiles,
    renderSummaryMarkdown,
) where

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (foldl')
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Vector as V

import TxDeepDiagnosisHost.Registry (
    AikenSource (..),
    DatumSchema (..),
    FieldType (..),
    ProtocolRegistry,
    SchemaConstructor (..),
    SchemaField (..),
    SchemaSource (..),
    TupleField (..),
    aikenSourceUrl,
    datumSchemaForHash,
 )
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc (..))
import TxDeepDiagnosisHost.Render.Names (
    PartyName (..),
    PartySource (..),
    paymentScriptHash,
    resolveAddress,
 )

{- | Which artifacts the caller wrote alongside @summary.md@.
Each Maybe holds the relative file name when written.
-}
data EmittedFiles = EmittedFiles
    { efParties :: !(Maybe FilePath)
    , efValueFlow :: !(Maybe FilePath)
    , efTopology :: !(Maybe FilePath)
    , efFailures :: !(Maybe FilePath)
    }

-- | Default 'EmittedFiles' with everything missing.
noEmittedFiles :: EmittedFiles
noEmittedFiles =
    EmittedFiles
        { efParties = Nothing
        , efValueFlow = Nothing
        , efTopology = Nothing
        , efFailures = Nothing
        }

renderSummaryMarkdown ::
    ProtocolRegistry ->
    DiagnosisDoc ->
    EmittedFiles ->
    Text
renderSummaryMarkdown reg doc files =
    Text.concat
        [ titleSection doc
        , headlineSection doc
        , verdictSection doc
        , failuresSection doc
        , balanceSection reg doc
        , feesResourcesSection doc
        , observationsSection reg doc
        , claimsSection doc
        , effectsSection doc
        , scriptsSection reg doc
        , withdrawalsSection doc
        , outputsSection reg doc
        , datumsSection reg doc
        , warningsSection doc
        , diagramsSection files
        ]

-- ---------------------------------------------------------------- --
-- Sections
-- ---------------------------------------------------------------- --

titleSection :: DiagnosisDoc -> Text
titleSection doc =
    let title = textPath doc ["result", "intent", "title"] "Transaction"
        subtitle =
            textPath
                doc
                ["result", "intent", "subtitle"]
                ""
     in "# "
            <> title
            <> "\n\n"
            <> ( if Text.null subtitle
                    then ""
                    else "_" <> subtitle <> "_\n\n"
               )
            <> "Tx id: `"
            <> textPath doc ["result", "intent", "tx_id"] ""
            <> "`\n\n"

headlineSection :: DiagnosisDoc -> Text
headlineSection doc =
    let subject = headlineSubject doc
        outcome = headlineOutcomePhrase (validationStatus doc)
        dominantBucket = case dominantOutputBucketLabel doc of
            Nothing -> ""
            Just bucket ->
                " and sends most value to the **"
                    <> bucket
                    <> "** bucket"
     in "**Headline:** "
            <> subject
            <> " "
            <> outcome
            <> dominantBucket
            <> ".\n\n"

verdictSection :: DiagnosisDoc -> Text
verdictSection doc =
    let topSummary = ddSummary doc
        verdict = validationStatus doc
     in "## Verdict\n\n"
            <> "- "
            <> topSummary
            <> "\n"
            <> "- ledger validation: **"
            <> verdict
            <> "**\n\n"

validationStatus :: DiagnosisDoc -> Text
validationStatus doc =
    case valuePath
        (ddValidate doc)
        ["result", "validation", "status"] of
        Just (String s) -> s
        _ -> case valuePath
            (ddValidate doc)
            [ "result"
            , "validation"
            , "valid_for_supplied_context"
            ] of
            Just (Bool True) -> "valid"
            Just (Bool False) -> "invalid"
            _ -> "unknown"

headlineSubject :: DiagnosisDoc -> Text
headlineSubject doc =
    case firstClaimLabel doc of
        Just label | not (Text.null label) -> "Claimed **" <> label <> "**"
        _ ->
            let title = textPath doc ["result", "intent", "title"] "Transaction"
             in case title of
                    "Signing summary" -> "This transaction"
                    "Transaction" -> "This transaction"
                    _ -> "**" <> title <> "**"

headlineOutcomePhrase :: Text -> Text
headlineOutcomePhrase status = case status of
    "valid" -> "is **valid**"
    "invalid" -> "is **invalid**"
    "incomplete" -> "is **incomplete** for the supplied context"
    "rejected" -> "was **rejected** for the supplied context"
    _ -> "has an **unknown** verdict"

firstClaimLabel :: DiagnosisDoc -> Maybe Text
firstClaimLabel doc =
    case valuePath (ddIntent doc) ["result", "intent", "claims"] of
        Just (Array xs) ->
            case [textOf "label" o "" | Object o <- V.toList xs] of
                (lab : _) | not (Text.null lab) -> Just lab
                _ -> Nothing
        _ -> Nothing

dominantOutputBucketLabel :: DiagnosisDoc -> Maybe Text
dominantOutputBucketLabel doc =
    case outputBuckets doc of
        [] -> Nothing
        (x : xs) ->
            let best = foldl' maxBucket (obLabel x, parseLov (obLovelace x)) xs
             in Just (fst best)
  where
    maxBucket best bucket =
        let current = (obLabel bucket, parseLov (obLovelace bucket))
         in if snd current > snd best then current else best

{- | Lists the facts that drive flow understanding: who owns the
inputs (per registry), what the metadata declares as the destination
(self-declared, separately listed because the inspector library
already warns it is unverified), and what the envelope structurally
cannot tell us (per-output addresses).

The reader is expected to compare the input parties against the
metadata destination on their own. Stating "self-swap detected"
would mean asserting an output flow direction that the envelope
does not actually expose.
-}
observationsSection :: ProtocolRegistry -> DiagnosisDoc -> Text
observationsSection reg doc =
    let inParties = inputParties reg doc
        outParties = outputParties reg doc
        metaDestinations = metadataDestinations doc
        crossover = inputOutputOverlap inParties outParties
        body =
            Text.concat
                [ "Input parties (registry-resolved):\n\n"
                , bulletList (map renderParty inParties)
                , "\n"
                , "Output parties (registry-resolved, from `intent.value.output_buckets[].addresses`):\n\n"
                , bulletList (map renderOutputParty outParties)
                , "\n"
                , metaSection metaDestinations
                , crossoverSection crossover
                ]
     in if null inParties && null outParties && null metaDestinations
            then ""
            else "## Observations\n\n" <> body
  where
    metaSection [] = ""
    metaSection ds =
        "Metadata-declared destination(s):\n\n"
            <> bulletList
                ( map
                    (\d -> "_" <> d <> "_ (self-declared, not verified)")
                    ds
                )
            <> "\n"
    crossoverSection [] = ""
    crossoverSection ms =
        "Inputs that also receive outputs (same payment credential on "
            <> "both sides):\n\n"
            <> bulletList ms
            <> "\n"

bulletList :: [Text] -> Text
bulletList = Text.concat . map (\x -> "- " <> x <> "\n")

renderParty :: (Int, Text, PartyName) -> Text
renderParty (i, lov, pn) =
    "input #"
        <> Text.pack (show i)
        <> " — **"
        <> pnLabel pn
        <> "** (`"
        <> partySource pn
        <> "`) — "
        <> lov
        <> " lovelace"

renderOutputParty :: (Text, PartyName) -> Text
renderOutputParty (bucket, pn) =
    bucket
        <> " bucket → **"
        <> pnLabel pn
        <> "** (`"
        <> partySource pn
        <> "`)"

partySource :: PartyName -> Text
partySource pn = Text.pack (show (pnSource pn))

{- | Output parties extracted from
@intent.value.output_buckets[].addresses[]@. One row per (bucket,
address); duplicates collapsed by 'pnLabel' to keep the list short
when many script outputs share a contract.
-}
outputParties :: ProtocolRegistry -> DiagnosisDoc -> [(Text, PartyName)]
outputParties reg doc =
    let path = ["result", "intent", "value", "output_buckets"]
        items = case valuePath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
        bucketEntries =
            [ (label, addrs)
            | Object o <- items
            , Just (String label) <- [KeyMap.lookup "label" o]
            , Just (Array as) <- [KeyMap.lookup "addresses" o]
            , let addrs = [a | String a <- V.toList as]
            ]
     in dedupByLabel
            [ (b, resolveAddress reg a)
            | (b, addrs) <- bucketEntries
            , a <- addrs
            ]

dedupByLabel :: [(Text, PartyName)] -> [(Text, PartyName)]
dedupByLabel =
    foldr keep []
  where
    keep x acc
        | any (\y -> fst x == fst y && pnLabel (snd x) == pnLabel (snd y)) acc =
            acc
        | otherwise = x : acc

{- | Pairs of (input-party label, "appears in output bucket B") where
the input's resolved party label also shows up in an output bucket's
addresses. The match is on registry-resolved label, so a treasury
that owns both input and output is detected even if its addresses use
different stake credentials.
-}
inputOutputOverlap :: [(Int, Text, PartyName)] -> [(Text, PartyName)] -> [Text]
inputOutputOverlap inputs outputs =
    [ "input #"
        <> Text.pack (show i)
        <> " — **"
        <> pnLabel ipn
        <> "** also appears as a destination in the **"
        <> bucket
        <> "** output bucket"
    | (i, _, ipn) <- inputs
    , pnSource ipn /= TruncatedHex
    , (bucket, opn) <- outputs
    , pnLabel ipn == pnLabel opn
    ]

inputParties :: ProtocolRegistry -> DiagnosisDoc -> [(Int, Text, PartyName)]
inputParties reg doc =
    let path = ["result", "validation", "resolved_inputs"]
        items = case valuePath (ddValidate doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in zipWith (\i v -> mkParty i v) [0 ..] items
            >>= maybe [] pure
  where
    mkParty i (Object o) = case KeyMap.lookup "tx_out" o of
        Just (Object txOut) -> case KeyMap.lookup "address_hex" txOut of
            Just (String addr) ->
                let lov = case KeyMap.lookup "coin_lovelace" txOut of
                        Just (String s) -> s
                        _ -> "0"
                 in Just (i, lov, resolveAddress reg addr)
            _ -> Nothing
        _ -> Nothing
    mkParty _ _ = Nothing

data OutputBucket = OutputBucket
    { obLabel :: !Text
    , obLovelace :: !Text
    }

outputBuckets :: DiagnosisDoc -> [OutputBucket]
outputBuckets doc =
    let path = ["result", "intent", "value", "output_buckets"]
        items = case valuePath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in mapMaybe parseBucket items
  where
    parseBucket (Object o) = do
        label <- case KeyMap.lookup "label" o of
            Just (String s) -> Just s
            _ -> Nothing
        let lov = case KeyMap.lookup "lovelace" o of
                Just (String s) -> s
                _ -> "0"
        Just OutputBucket{obLabel = label, obLovelace = lov}
    parseBucket _ = Nothing

metadataDestinations :: DiagnosisDoc -> [Text]
metadataDestinations doc =
    let path = ["result", "intent", "metadata_claims"]
        items = case valuePath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in [d | Object o <- items, Just (String d) <- [KeyMap.lookup "destination" o], not (Text.null d)]

countOutputs :: DiagnosisDoc -> Maybe Int
countOutputs doc = case valuePath
    (ddIntent doc)
    ["result", "intent", "features", "output_count"] of
    Just (Number n) -> Just (floor n)
    _ -> Nothing

balanceSection :: ProtocolRegistry -> DiagnosisDoc -> Text
balanceSection reg doc =
    let inputs = inputParties reg doc
        outBuckets = outputBuckets doc
        feeLov = feeLovelace doc
        inTotal = sum [parseLov lov | (_, lov, _) <- inputs]
        outTotal = sum [parseLov lov | b <- outBuckets, let { lov = obLovelace b }] + parseLov feeLov
        delta = inTotal - outTotal
        inputsTable =
            "### Inputs\n\n"
                <> "| Source | ADA |\n"
                <> "|--------|----:|\n"
                <> Text.concat
                    [ "| "
                        <> escapeTable
                            ( "input #"
                                <> Text.pack (show i)
                                <> " — "
                                <> pnLabel pn
                            )
                        <> " | "
                        <> formatAdaSimple (parseLov lov)
                        <> " |\n"
                    | (i, lov, pn) <- inputs
                    ]
                <> "| **Total inputs** | **"
                <> formatAdaSimple inTotal
                <> "** |\n\n"
        outputsTable =
            "### Outputs + fee\n\n"
                <> "| Destination | ADA |\n"
                <> "|-------------|----:|\n"
                <> Text.concat
                    [ "| "
                        <> escapeTable (obLabel bucket <> " bucket")
                        <> " | "
                        <> formatAdaSimple (parseLov (obLovelace bucket))
                        <> " |\n"
                    | bucket <- outBuckets
                    ]
                <> "| fee | "
                <> formatAdaSimple (parseLov feeLov)
                <> " |\n"
                <> "| **Total outputs + fee** | **"
                <> formatAdaSimple outTotal
                <> "** |\n\n"
        balanceLine
            | delta == 0 =
                "_Balance: inputs = outputs + fee_\n\n"
            | delta > 0 =
                "**Unaccounted: "
                    <> formatAdaSimple delta
                    <> " missing — `ValueNotConservedUTxO`**\n\n"
            | otherwise =
                "**Over-spent: "
                    <> formatAdaSimple (negate delta)
                    <> " more in outputs + fee than inputs — `ValueNotConservedUTxO`**\n\n"
     in if null inputs && null outBuckets && parseLov feeLov == 0
            then ""
            else
                "## Balance\n\n"
                    <> inputsTable
                    <> outputsTable
                    <> balanceLine

feesResourcesSection :: DiagnosisDoc -> Text
feesResourcesSection doc =
    let feeRow =
            Just
                ( "Fee"
                , formatAdaSimple (parseLov (feeLovelace doc)) <> " ADA"
                , feeLovelace doc <> " lovelace"
                )
        txSizeRow = case txSizeBytes doc of
            Just n ->
                Just
                    ( "Tx size"
                    , formatCount n <> " bytes"
                    , "from the intent envelope"
                    )
            Nothing -> Nothing
        redeemerRow =
            Just
                ( "Redeemers"
                , Text.pack (show (redeemerCount doc))
                , "committed redeemers in the current intent view"
                )
        exUnitsRow = case committedExUnits doc of
            Just (mem, steps) ->
                Just
                    ( "Committed ex-units"
                    , formatCount mem <> " memory / " <> formatCount steps <> " steps"
                    , "summed from per-redeemer committed budgets"
                    )
            Nothing -> Nothing
        rows = mapMaybe id [feeRow, txSizeRow, redeemerRow, exUnitsRow]
     in if null rows
            then ""
            else
                "## Fees & resources\n\n"
                    <> "| Label | Value | Detail |\n"
                    <> "|-------|-------|--------|\n"
                    <> Text.concat
                        [ "| "
                            <> escapeTable label
                            <> " | "
                            <> escapeTable value
                            <> " | "
                            <> escapeTable detail
                            <> " |\n"
                        | (label, value, detail) <- rows
                        ]
                    <> "\n"

feeLovelace :: DiagnosisDoc -> Text
feeLovelace doc = case valuePath (ddIntent doc) ["result", "intent", "fee_lovelace"] of
    Just (String s) -> s
    _ -> "0"

txSizeBytes :: DiagnosisDoc -> Maybe Integer
txSizeBytes doc = case valuePath (ddIntent doc) ["result", "intent", "tx_size_bytes"] of
    Just (Number n) -> Just (floor n)
    Just (String s) -> case reads (Text.unpack s) of
        [(n, "")] -> Just n
        _ -> Nothing
    _ -> Nothing

redeemerCount :: DiagnosisDoc -> Int
redeemerCount doc =
    case valuePath (ddIntent doc) ["result", "intent", "features", "redeemer_count"] of
        Just (Number n) -> floor n
        _ -> length (scriptRows doc)

committedExUnits :: DiagnosisDoc -> Maybe (Integer, Integer)
committedExUnits doc =
    let units =
            [ (mem, steps)
            | Object o <- scriptRows doc
            , Just (Object ex) <- [KeyMap.lookup "ex_units_committed" o]
            , Just mem <- [stringNumber "memory" ex]
            , Just steps <- [stringNumber "steps" ex]
            ]
     in case units of
            [] -> Nothing
            _ ->
                Just
                    ( sum [mem | (mem, _) <- units]
                    , sum [steps | (_, steps) <- units]
                    )

scriptRows :: DiagnosisDoc -> [Value]
scriptRows doc =
    case valuePath (ddIntent doc) ["result", "intent", "scripts"] of
        Just (Array xs) -> V.toList xs
        _ -> []

stringNumber :: Text -> KeyMap.KeyMap Value -> Maybe Integer
stringNumber key o = case KeyMap.lookup (Key.fromText key) o of
    Just (String s) -> case reads (Text.unpack s) of
        [(n, "")] -> Just n
        _ -> Nothing
    Just (Number n) -> Just (floor n)
    _ -> Nothing

formatCount :: Integer -> Text
formatCount = withThousandsSeparators . Text.pack . show

scriptOutputCount :: DiagnosisDoc -> Maybe Int
scriptOutputCount doc =
    let path = ["result", "intent", "value", "output_buckets"]
        items = case valuePath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
        scriptB =
            [ floor n
            | Object o <- items
            , Just (String "Script") <- [KeyMap.lookup "label" o]
            , Just (Number n) <- [KeyMap.lookup "tx_out_count" o]
            ]
     in case scriptB of
            (n : _) -> Just n
            [] -> Nothing

{- | Per-output table from @intent.value.outputs[]@. Lets the reader
see exactly how a script bucket's lovelace splits across individual
outputs and which datum (by hash or by inline cbor preview)
parameterises each one. Critical for swap analysis: SundaeSwap V3
order outputs encode min-receive amounts and beneficiaries in their
inline datums.
-}
outputsSection :: ProtocolRegistry -> DiagnosisDoc -> Text
outputsSection reg doc =
    let path = ["result", "intent", "value", "outputs"]
        items = case valuePath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in if null items
            then ""
            else
                "## Outputs\n\n"
                    <> "| # | Bucket | Destination | ADA | Datum |\n"
                    <> "|---|--------|-------------|----:|-------|\n"
                    <> Text.concat (map (renderOutputRow reg) items)
                    <> "\n"

renderOutputRow :: ProtocolRegistry -> Value -> Text
renderOutputRow reg v = case v of
    Object o ->
        let idx = case KeyMap.lookup "index" o of
                Just (Number n) -> Text.pack (show (floor n :: Int))
                _ -> "?"
            bucket = case KeyMap.lookup "bucket" o of
                Just (String s) -> s
                _ -> ""
            addr = case KeyMap.lookup "address_hex" o of
                Just (String s) -> s
                _ -> ""
            party = pnLabel (resolveAddress reg addr)
            lov = case KeyMap.lookup "coin_lovelace" o of
                Just (String s) -> s
                _ -> "0"
            ada = formatAdaSimple (parseLov lov)
            datumCell = case KeyMap.lookup "datum" o of
                Just (Object d) -> renderDatumCell d
                _ -> ""
         in "| "
                <> idx
                <> " | "
                <> escapeTable bucket
                <> " | "
                <> escapeTable party
                <> " | "
                <> ada
                <> " | "
                <> escapeTable datumCell
                <> " |\n"
    _ -> ""

renderDatumCell :: KeyMap.KeyMap Value -> Text
renderDatumCell d = case KeyMap.lookup "kind" d of
    Just (String "no_datum") -> "—"
    Just (String "datum_hash") -> case KeyMap.lookup "hash" d of
        Just (String h) -> "hash `" <> Text.take 10 h <> "…`"
        _ -> "hash"
    Just (String "inline_datum") -> case KeyMap.lookup "cbor_hex" d of
        Just (String h) -> "inline `" <> Text.take 14 h <> "…` (" <> Text.pack (show (Text.length h `div` 2)) <> "B)"
        _ -> "inline"
    _ -> ""

parseLov :: Text -> Integer
parseLov t = case reads (Text.unpack t) of
    [(n, "")] -> n
    _ -> 0

{- | Pretty-prints the per-output decoded datum AST. Each output that
carries an @inline_datum@ with a @decoded@ field gets its own
collapsible @<details>@ so the full document remains scrollable.
The pretty-printer renders the AST as an indented pseudo-Lisp form
which compresses better than JSON in the markdown view.

Outputs whose datum is a hash-only reference, or a @no_datum@, are
omitted. Identical datums (same hex string) are deduplicated — a
SundaeSwap order with N identical outputs only shows the datum
once with a count.
-}
datumsSection :: ProtocolRegistry -> DiagnosisDoc -> Text
datumsSection reg doc =
    let path = ["result", "intent", "value", "outputs"]
        items = case valuePath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
        decoded = mapMaybeDecoded reg items
        groups = groupByCbor decoded
     in if null groups
            then ""
            else
                "## Datums\n\n"
                    <> Text.concat (map renderDatumGroup groups)

mapMaybeDecoded ::
    ProtocolRegistry ->
    [Value] ->
    [DecodedDatum]
mapMaybeDecoded reg = mapMaybe step
  where
    step (Object o) = do
        idx <- case KeyMap.lookup "index" o of
            Just (Number n) -> Just (floor n :: Int)
            _ -> Nothing
        addr <- case KeyMap.lookup "address_hex" o of
            Just (String s) -> Just s
            _ -> Nothing
        d <- case KeyMap.lookup "datum" o of
            Just (Object dm) -> Just dm
            _ -> Nothing
        case KeyMap.lookup "kind" d of
            Just (String "inline_datum") -> do
                cbor <- case KeyMap.lookup "cbor_hex" d of
                    Just (String s) -> Just s
                    _ -> Nothing
                ast <- KeyMap.lookup "decoded" d
                let scriptHash = paymentScriptHash addr
                    schema = scriptHash >>= datumSchemaForHash reg
                Just
                    DecodedDatum
                        { ddIndex = idx
                        , ddDestination = pnLabel (resolveAddress reg addr)
                        , ddCbor = cbor
                        , ddAst = ast
                        , ddSchema = schema
                        }
            _ -> Nothing
    step _ = Nothing

data DecodedDatum = DecodedDatum
    { ddIndex :: !Int
    , ddDestination :: !Text
    , ddCbor :: !Text
    , ddAst :: !Value
    , ddSchema :: !(Maybe DatumSchema)
    }

groupByCbor :: [DecodedDatum] -> [(DecodedDatum, [Int])]
groupByCbor = foldr add []
  where
    add d acc = case partitionBy (\(rep, _) -> ddCbor rep == ddCbor d) acc of
        (Just (rep, idxs), rest) -> (rep, ddIndex d : idxs) : rest
        (Nothing, _) -> (d, [ddIndex d]) : acc

partitionBy :: (a -> Bool) -> [a] -> (Maybe a, [a])
partitionBy _ [] = (Nothing, [])
partitionBy p (x : xs)
    | p x = (Just x, xs)
    | otherwise = case partitionBy p xs of
        (m, rest) -> (m, x : rest)

renderDatumGroup :: (DecodedDatum, [Int]) -> Text
renderDatumGroup (rep, indices) =
    let title = case sortedIndices indices of
            [i] -> "Output #" <> Text.pack (show i) <> " — " <> ddDestination rep
            xs ->
                "Outputs "
                    <> Text.intercalate ", " ["#" <> Text.pack (show i) | i <- xs]
                    <> " — "
                    <> ddDestination rep
                    <> " ("
                    <> Text.pack (show (length xs))
                    <> " identical)"
        body = case ddSchema rep of
            Just schema ->
                provenanceLine schema
                    <> "\n```\n"
                    <> prettySchemaBound schema (ddAst rep)
                    <> "```\n"
            Nothing ->
                "_Untyped — no datum schema registered for this script hash._\n\n"
                    <> "```\n"
                    <> prettyPlutusData 0 (ddAst rep)
                    <> "```\n"
     in "<details><summary>"
            <> escapeTable title
            <> "</summary>\n\n"
            <> body
            <> "\n</details>\n\n"

{- | The provenance disclaimer shown above every typed datum body.
The renderer will not emit typed names without one — every
'SchemaSource' constructor produces a non-empty line.
-}
provenanceLine :: DatumSchema -> Text
provenanceLine schema =
    let prefix = "_Field names "
     in case dsSource schema of
            SourcePlutusJson ->
                prefix <> "from the contract's CIP-57 plutus.json blueprint._\n"
            SourceAiken src ->
                prefix
                    <> "interpreted from the upstream Aiken source: ["
                    <> asRepo src
                    <> "@"
                    <> Text.take 10 (asCommit src)
                    <> "]("
                    <> aikenSourceUrl src
                    <> ")"
                    <> maybe "" (\n -> " — " <> n) (asNote src)
                    <> "._\n"
            SourceManual note ->
                prefix
                    <> "interpreted from manual analysis (no upstream typed source): "
                    <> note
                    <> "._\n"

{- | Walk the AST against a 'DatumSchema' and produce typed prose. The
top-level Constr index selects a constructor from 'dsConstructors';
fields are named per the schema. When the AST shape disagrees with
the schema (e.g. the Constr index is unknown), the whole body falls
back to the untyped pretty-printer with a one-line note so the
discrepancy is visible.
-}
prettySchemaBound :: DatumSchema -> Value -> Text
prettySchemaBound schema ast =
    case ast of
        Object o
            | Just (String "constr") <- KeyMap.lookup "kind" o
            , Just (Number n) <- KeyMap.lookup "index" o
            , let ix = floor n :: Integer
            , Just sc <- findConstructor ix (dsConstructors schema)
            , Just (Array fs) <- KeyMap.lookup "fields" o ->
                dsName schema
                    <> " (= "
                    <> scName sc
                    <> ")\n"
                    <> renderFields 1 sc (V.toList fs)
        _ ->
            "_AST shape disagrees with schema; rendering untyped._\n\n"
                <> prettyPlutusData 0 ast

findConstructor :: Integer -> [SchemaConstructor] -> Maybe SchemaConstructor
findConstructor ix = foldr step Nothing
  where
    step c acc = if scIndex c == ix then Just c else acc

renderFields :: Int -> SchemaConstructor -> [Value] -> Text
renderFields lvl sc values =
    let pad = Text.replicate (lvl * 2) " "
        fields = scFields sc
        zipped = zip fields (values <> repeat Null)
        usedFieldCount = length fields
        extras = drop usedFieldCount values
     in Text.concat (map (renderTypedField lvl pad) zipped)
            <> if null extras
                then ""
                else
                    pad
                        <> "_("
                        <> Text.pack (show (length extras))
                        <> " extra fields beyond schema, rendering untyped:)_\n"
                        <> Text.concat
                            (map (prettyPlutusData (lvl + 1)) extras)

renderTypedField :: Int -> Text -> (SchemaField, Value) -> Text
renderTypedField lvl pad (SchemaField name ty, v) =
    pad <> sfBullet name <> renderTyped (lvl + 1) ty v

sfBullet :: Text -> Text
sfBullet name = name <> ": "

{- | Render a Plutus AST node bound to a 'FieldType'. Recurses through
'FtList', 'FtConstr', 'FtSum'. 'FtData' falls through to the untyped
pretty-printer so opaque @extensions@ fields stay visible.
-}
renderTyped :: Int -> FieldType -> Value -> Text
renderTyped lvl ty v = case (ty, v) of
    (FtBytes hint, Object o)
        | Just (String "bytes") <- KeyMap.lookup "kind" o ->
            renderBytes hint o
    (FtInt hint, Object o)
        | Just (String "int") <- KeyMap.lookup "value" o ->
            renderInt hint o
        | Just (String "int") <- KeyMap.lookup "kind" o ->
            renderInt hint o
    (FtList elemTy, Object o)
        | Just (String "list") <- KeyMap.lookup "kind" o
        , Just (Array xs) <- KeyMap.lookup "items" o ->
            "List "
                <> Text.pack (show (V.length xs))
                <> "\n"
                <> Text.concat
                    [ Text.replicate (lvl * 2) " "
                        <> "- "
                        <> renderTyped (lvl + 1) elemTy x
                    | x <- V.toList xs
                    ]
    (FtTuple slots, Object o)
        | Just (String "list") <- KeyMap.lookup "kind" o
        , Just (Array xs) <- KeyMap.lookup "items" o ->
            let pad = Text.replicate (lvl * 2) " "
                pairs =
                    take
                        (length slots)
                        (zip slots (V.toList xs <> repeat Null))
             in "(\n"
                    <> Text.concat
                        [ pad
                            <> tfName slot
                            <> ": "
                            <> renderTyped (lvl + 1) (tfType slot) val
                        | (slot, val) <- pairs
                        ]
                    <> Text.replicate (max 0 (lvl - 1) * 2) " "
                    <> ")\n"
    (FtConstr sc, Object o)
        | Just (String "constr") <- KeyMap.lookup "kind" o
        , Just (Number n) <- KeyMap.lookup "index" o
        , floor n == scIndex sc
        , Just (Array fs) <- KeyMap.lookup "fields" o ->
            scName sc
                <> "\n"
                <> renderFields lvl sc (V.toList fs)
    (FtSum variants, Object o)
        | Just (String "constr") <- KeyMap.lookup "kind" o
        , Just (Number n) <- KeyMap.lookup "index" o
        , let ix = floor n :: Integer
        , Just sc <- findConstructor ix variants
        , Just (Array fs) <- KeyMap.lookup "fields" o ->
            scName sc
                <> "\n"
                <> renderFields lvl sc (V.toList fs)
    (FtData, _) ->
        "_(Data, untyped)_\n"
            <> prettyPlutusData lvl v
    _ ->
        "_(schema/AST mismatch, untyped)_\n"
            <> prettyPlutusData lvl v

renderBytes :: Maybe Text -> KeyMap.KeyMap Value -> Text
renderBytes hint o =
    let hex = case KeyMap.lookup "hex" o of
            Just (String s) -> s
            _ -> ""
        len = case KeyMap.lookup "len" o of
            Just (Number n) -> floor n :: Int
            _ -> 0
        utf = case KeyMap.lookup "utf8" o of
            Just (String s) -> Just s
            _ -> Nothing
        hexShort
            | Text.length hex <= 32 = hex
            | otherwise = Text.take 16 hex <> "…" <> Text.takeEnd 8 hex
        utfTail = case utf of
            Just s -> "  // \"" <> s <> "\""
            Nothing -> ""
        hintTail = case hint of
            Just h -> "  // " <> h
            Nothing -> ""
     in "Bytes "
            <> Text.pack (show len)
            <> "B "
            <> hexShort
            <> hintTail
            <> utfTail
            <> "\n"

renderInt :: Maybe Text -> KeyMap.KeyMap Value -> Text
renderInt hint o =
    let s = case KeyMap.lookup "value" o of
            Just (String x) -> x
            _ -> "?"
        hintTail = case hint of
            Just h -> "  // " <> h
            Nothing -> ""
     in "Int " <> s <> hintTail <> "\n"

sortedIndices :: [Int] -> [Int]
sortedIndices = foldr insertSorted []
  where
    insertSorted x [] = [x]
    insertSorted x (y : ys)
        | x <= y = x : y : ys
        | otherwise = y : insertSorted x ys

{- | Pseudo-Lisp pretty-print of a Plutus Data AST node. Indented two
spaces per nesting level. Constr is rendered with its constructor
index; bytes show their hex (truncated for display) plus a UTF-8
preview when present; ints render as decimal.
-}
prettyPlutusData :: Int -> Value -> Text
prettyPlutusData lvl v =
    let pad = Text.replicate (lvl * 2) " "
     in case v of
            Object o -> case KeyMap.lookup "kind" o of
                Just (String "constr") ->
                    let idx = case KeyMap.lookup "index" o of
                            Just (Number n) -> Text.pack (show (floor n :: Integer))
                            _ -> "?"
                        fields = case KeyMap.lookup "fields" o of
                            Just (Array xs) -> V.toList xs
                            _ -> []
                     in pad
                            <> "Constr "
                            <> idx
                            <> "\n"
                            <> Text.concat
                                (map (prettyPlutusData (lvl + 1)) fields)
                Just (String "list") ->
                    let items = case KeyMap.lookup "items" o of
                            Just (Array xs) -> V.toList xs
                            _ -> []
                     in pad
                            <> "List "
                            <> Text.pack (show (length items))
                            <> "\n"
                            <> Text.concat
                                (map (prettyPlutusData (lvl + 1)) items)
                Just (String "map") ->
                    let entries = case KeyMap.lookup "entries" o of
                            Just (Array xs) -> V.toList xs
                            _ -> []
                     in pad
                            <> "Map\n"
                            <> Text.concat
                                (map (prettyMapEntry (lvl + 1)) entries)
                Just (String "int") -> case KeyMap.lookup "value" o of
                    Just (String s) -> pad <> "Int " <> s <> "\n"
                    _ -> pad <> "Int ?\n"
                Just (String "bytes") ->
                    let hex = case KeyMap.lookup "hex" o of
                            Just (String s) -> s
                            _ -> ""
                        len = case KeyMap.lookup "len" o of
                            Just (Number n) -> floor n :: Int
                            _ -> 0
                        utf = case KeyMap.lookup "utf8" o of
                            Just (String s) -> Just s
                            _ -> Nothing
                        hexShort
                            | Text.length hex <= 32 = hex
                            | otherwise = Text.take 16 hex <> "…" <> Text.takeEnd 8 hex
                        utfTail = case utf of
                            Just s -> "  // \"" <> s <> "\""
                            Nothing -> ""
                     in pad
                            <> "Bytes "
                            <> Text.pack (show len)
                            <> "B "
                            <> hexShort
                            <> utfTail
                            <> "\n"
                _ -> pad <> "?\n"
            _ -> pad <> "?\n"

prettyMapEntry :: Int -> Value -> Text
prettyMapEntry lvl v = case v of
    Object o ->
        let pad = Text.replicate (lvl * 2) " "
            k = fromMaybe Null (KeyMap.lookup "k" o)
            mv = fromMaybe Null (KeyMap.lookup "v" o)
         in pad
                <> "k:\n"
                <> prettyPlutusData (lvl + 1) k
                <> pad
                <> "v:\n"
                <> prettyPlutusData (lvl + 1) mv
    _ -> ""

{- | Per-redeemer table from @intent.scripts[]@. Each row identifies
the redeemer's purpose, what it targets, the ex_units it commits, and
a CBOR preview so the reader can spot-check the redeemer body without
re-running the inspector.
-}
scriptsSection :: ProtocolRegistry -> DiagnosisDoc -> Text
scriptsSection reg doc =
    let path = ["result", "intent", "scripts"]
        items = case valuePath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in if null items
            then ""
            else
                "## Smart-contract calls\n\n"
                    <> "| # | Purpose | Target | ex_units (mem / steps) | Redeemer |\n"
                    <> "|---|---------|--------|------------------------|----------|\n"
                    <> Text.concat (zipWith (renderScriptRow doc) [0 ..] items)
                    <> "\n"

renderScriptRow :: DiagnosisDoc -> Int -> Value -> Text
renderScriptRow doc n v = case v of
    Object o ->
        let purpose = case KeyMap.lookup "purpose" o of
                Just (String s) -> s
                _ -> "?"
            idx = case KeyMap.lookup "index" o of
                Just (Number x) -> Text.pack (show (floor x :: Int))
                _ -> "?"
            target = case purpose of
                "spending" -> case KeyMap.lookup "input" o of
                    Just (Object inp) ->
                        let txid = case KeyMap.lookup "tx_id" inp of
                                Just (String s) -> Text.take 16 s <> "…"
                                _ -> "?"
                            i = case KeyMap.lookup "index" inp of
                                Just (Number x) -> Text.pack (show (floor x :: Int))
                                _ -> "?"
                         in "input " <> txid <> "#" <> i
                    _ -> "input #" <> idx
                "rewarding" -> withdrawalTarget doc idx
                _ -> purpose <> " #" <> idx
            exu = case KeyMap.lookup "ex_units_committed" o of
                Just (Object e) ->
                    let mem = case KeyMap.lookup "memory" e of
                            Just (String s) -> s
                            _ -> "?"
                        st = case KeyMap.lookup "steps" e of
                            Just (String s) -> s
                            _ -> "?"
                     in mem <> " / " <> st
                _ -> "?"
            cbor = case KeyMap.lookup "redeemer_cbor_hex" o of
                Just (String s) ->
                    "`" <> Text.take 14 s <> "…` (" <> Text.pack (show (Text.length s `div` 2)) <> "B)"
                _ -> ""
         in "| "
                <> Text.pack (show n)
                <> " | "
                <> escapeTable purpose
                <> " | "
                <> escapeTable target
                <> " | "
                <> escapeTable exu
                <> " | "
                <> escapeTable cbor
                <> " |\n"
    _ -> ""

withdrawalsSection :: DiagnosisDoc -> Text
withdrawalsSection doc =
    let path = ["result", "intent", "withdrawals"]
        items = case valuePath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in if null items
            then ""
            else
                "## Withdrawals\n\n"
                    <> "| # | Reward account | Amount |\n"
                    <> "|---|----------------|-------:|\n"
                    <> Text.concat (map renderWithdrawalRow items)
                    <> "\n"

renderWithdrawalRow :: Value -> Text
renderWithdrawalRow v = case v of
    Object o ->
        let idx = case KeyMap.lookup "index" o of
                Just (Number n) -> Text.pack (show (floor n :: Int))
                _ -> "?"
            amount = case KeyMap.lookup "amount_lovelace" o of
                Just (String s) -> formatAdaSimple (parseLov s)
                _ -> formatAdaSimple 0
            account = withdrawalAccountLabel o
         in "| "
                <> idx
                <> " | "
                <> escapeTable account
                <> " | "
                <> amount
                <> " |\n"
    _ -> ""

withdrawalTarget :: DiagnosisDoc -> Text -> Text
withdrawalTarget doc idxText =
    case readIntText idxText >>= findWithdrawal doc of
        Just o ->
            let amount = case KeyMap.lookup "amount_lovelace" o of
                    Just (String s) -> formatAdaSimple (parseLov s) <> " ADA"
                    _ -> formatAdaSimple 0 <> " ADA"
             in "withdrawal #" <> idxText <> " " <> withdrawalCredentialLabel o <> " (" <> amount <> ")"
        Nothing -> "withdrawal #" <> idxText

findWithdrawal :: DiagnosisDoc -> Int -> Maybe (KeyMap.KeyMap Value)
findWithdrawal doc targetIndex =
    case valuePath (ddIntent doc) ["result", "intent", "withdrawals"] of
        Just (Array xs) -> go (V.toList xs)
        _ -> Nothing
  where
    go [] = Nothing
    go (Object o : rest) = case KeyMap.lookup "index" o of
        Just (Number n)
            | floor n == targetIndex -> Just o
        _ -> go rest
    go (_ : rest) = go rest

withdrawalAccountLabel :: KeyMap.KeyMap Value -> Text
withdrawalAccountLabel o =
    let network = textOf "network" o ""
        credential = withdrawalCredentialLabel o
        rewardHex = case KeyMap.lookup "reward_account_hex" o of
            Just (String s) -> "`" <> previewHex 20 s <> "`"
            _ -> ""
        parts = filter (not . Text.null) [network, credential, rewardHex]
     in Text.intercalate " / " parts

withdrawalCredentialLabel :: KeyMap.KeyMap Value -> Text
withdrawalCredentialLabel o = case KeyMap.lookup "credential" o of
    Just (Object cred) ->
        let kind = textOf "kind" cred "credential"
            hashText = textOf "hash" cred "?"
         in kind <> " " <> hashText
    _ -> "credential ?"

previewHex :: Int -> Text -> Text
previewHex n hexText
    | Text.length hexText <= n = hexText
    | otherwise = Text.take n hexText <> "…"

readIntText :: Text -> Maybe Int
readIntText t = case reads (Text.unpack t) of
    [(n, "")] -> Just n
    _ -> Nothing

claimsSection :: DiagnosisDoc -> Text
claimsSection doc =
    let intent = ddIntent doc
        claims = case valuePath
            intent
            ["result", "intent", "claims"] of
            Just (Array xs) -> V.toList xs
            _ -> []
     in if null claims
            then ""
            else
                "## Claims\n\n"
                    <> "| Label | Value | Detail |\n"
                    <> "|-------|-------|--------|\n"
                    <> Text.concat (map renderClaim claims)
                    <> "\n"
  where
    renderClaim (Object o) =
        let lab = textOf "label" o ""
            val = textOf "value" o ""
            det = textOf "detail" o ""
         in "| "
                <> escapeTable lab
                <> " | "
                <> escapeTable val
                <> " | "
                <> escapeTable (selfDeclaredDetail det)
                <> " |\n"
    renderClaim _ = ""

selfDeclaredDetail :: Text -> Text
selfDeclaredDetail det =
    let stripped = Text.replace " / self-declared" "" det
     in if Text.null stripped
            then "self-declared, not verified"
            else "self-declared, not verified / " <> stripped

effectsSection :: DiagnosisDoc -> Text
effectsSection doc =
    let intent = ddIntent doc
        sections = case valuePath
            intent
            ["result", "intent", "sections"] of
            Just (Array xs) -> V.toList xs
            _ -> []
     in Text.concat (map renderSectionHeading sections)
  where
    renderSectionHeading (Object o) =
        let title = textOf "title" o ""
            rows = case KeyMap.lookup "rows" o of
                Just (Array xs) -> V.toList xs
                _ -> []
            empty = textOf "empty" o ""
         in "## "
                <> title
                <> "\n\n"
                <> ( if null rows
                        then "_" <> empty <> "_\n\n"
                        else
                            "| Label | Value | Detail |\n"
                                <> "|-------|-------|--------|\n"
                                <> Text.concat (map renderRow rows)
                                <> "\n"
                   )
    renderSectionHeading _ = ""
    renderRow (Object o) =
        let lab = textOf "label" o ""
            val = textOf "value" o ""
            det = textOf "detail" o ""
         in "| "
                <> escapeTable lab
                <> " | "
                <> escapeTable val
                <> " | "
                <> escapeTable det
                <> " |\n"
    renderRow _ = ""

failuresSection :: DiagnosisDoc -> Text
failuresSection doc =
    let items = case valuePath
            (ddValidate doc)
            ["result", "validation", "failures"] of
            Just (Array xs) -> V.toList xs
            _ -> []
     in if null items
            then ""
            else
                "## Validation failures\n\n"
                    <> Text.concat (map renderFail items)
  where
    renderFail (Object o) =
        let rule = textOf "rule" o ""
            predicate = textOf "predicate" o ""
            msg = textOf "message" o ""
         in "### "
                <> failureLead predicate msg
                <> "\n\n"
                <> "_Raw rule:_ `"
                <> rule
                <> " — "
                <> shortName predicate
                <> "`\n\n"
                <> humanise predicate msg
                <> "\n"
    renderFail _ = ""

failureLead :: Text -> Text -> Text
failureLead predicate _msg
    | "ValueNotConservedUTxO" `Text.isInfixOf` predicate =
        let supplied = extractCoin "supplied: MaryValue (Coin " predicate
            expected = extractCoin "expected: MaryValue (Coin " predicate
            delta = supplied - expected
         in if delta > 0
                then
                    "Inputs and outputs do not conserve value: "
                        <> formatAdaSimple delta
                        <> " ADA missing"
                else
                    "Inputs and outputs do not conserve value: "
                        <> formatAdaSimple (abs delta)
                        <> " ADA over-spent"
    | "MissingVKeyWitnessesUTXOW" `Text.isInfixOf` predicate =
        let missing = length (extractKeyHashes predicate)
            noun = if missing == 1 then "required signer witness is" else "required signer witnesses are"
         in Text.pack (show missing) <> " " <> noun <> " missing"
    | "BadInputsUTxO" `Text.isInfixOf` predicate =
        "One or more declared inputs are missing from the supplied context"
    | "OutsideValidityIntervalUTxO" `Text.isInfixOf` predicate =
        "The transaction falls outside its validity interval"
    | otherwise = shortName predicate

{- | Convert a verbose ledger predicate into one human-readable name
that the reader can grep for. Falls back to the first 60 chars of the
predicate so unmapped failures still produce useful output.
-}
shortName :: Text -> Text
shortName p
    | "ValueNotConservedUTxO" `Text.isInfixOf` p = "ValueNotConservedUTxO"
    | "MissingVKeyWitnessesUTXOW" `Text.isInfixOf` p =
        "MissingVKeyWitnessesUTXOW"
    | "BadInputsUTxO" `Text.isInfixOf` p = "BadInputsUTxO"
    | "OutsideValidityIntervalUTxO" `Text.isInfixOf` p =
        "OutsideValidityInterval"
    | otherwise = Text.take 60 p

{- | Translate the predicate into a few lines of ADA-denominated /
hash-listed prose. Falls back to the raw message in a fenced block
when the predicate shape is not recognised.
-}
humanise :: Text -> Text -> Text
humanise predicate msg
    | "ValueNotConservedUTxO" `Text.isInfixOf` predicate =
        humaniseValueNotConserved predicate
    | "MissingVKeyWitnessesUTXOW" `Text.isInfixOf` predicate =
        humaniseMissingVKey predicate
    | otherwise = "```\n" <> msg <> "\n```\n"

humaniseValueNotConserved :: Text -> Text
humaniseValueNotConserved predicate =
    let supplied = extractCoin "supplied: MaryValue (Coin " predicate
        expected = extractCoin "expected: MaryValue (Coin " predicate
        delta = supplied - expected
        direction
            | delta > 0 =
                "Inputs supply **"
                    <> formatAdaSimple delta
                    <> " ADA** more than outputs + fee — that ADA is "
                    <> "unaccounted for."
            | delta < 0 =
                "Outputs + fee claim **"
                    <> formatAdaSimple (negate delta)
                    <> " ADA** more than inputs supply — over-spent."
            | otherwise = "Both sides equal but the ledger still rejected — re-check predicate."
     in "- supplied (inputs): **"
            <> formatAdaSimple supplied
            <> " ADA**\n"
            <> "- expected (outputs + fee): **"
            <> formatAdaSimple expected
            <> " ADA**\n"
            <> "- "
            <> direction
            <> "\n"

humaniseMissingVKey :: Text -> Text
humaniseMissingVKey predicate =
    let hashes = extractKeyHashes predicate
     in if null hashes
            then "No vkey witness hashes recovered from the predicate.\n"
            else
                "The following payment-key hashes are listed as required \
                \signers but are missing from the witness set:\n\n"
                    <> Text.concat (map (\h -> "- `" <> h <> "`\n") hashes)
                    <> "\n_Tip:_ each hash above is the `payment_key_hash` of one \
                       \of the resolved inputs (or an explicitly declared required \
                       \signer in the tx body). Compare with the `Observations` \
                       \section above to see which party each hash belongs to.\n"

{- | Pull a Coin integer out of @\"supplied: MaryValue (Coin 12345)\"@
or @\"expected: ... (Coin 12345)\"@. Returns 0 on no match.
-}
extractCoin :: Text -> Text -> Integer
extractCoin marker predicate =
    case Text.breakOn marker predicate of
        (_, rest)
            | not (Text.null rest) ->
                let after = Text.drop (Text.length marker) rest
                    digits = Text.takeWhile (\c -> c >= '0' && c <= '9') after
                 in case reads (Text.unpack digits) of
                        [(n, "")] -> n
                        _ -> 0
        _ -> 0

extractKeyHashes :: Text -> [Text]
extractKeyHashes =
    filter isHashLike
        . map cleanup
        . drop 1
        . Text.splitOn "KeyHash"
  where
    cleanup t =
        Text.takeWhile
            (/= '"')
            (Text.drop 1 (Text.dropWhile (/= '"') t))
    isHashLike t =
        Text.length t == 56 && Text.all isHex t
    isHex c =
        (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')

{- | Format an Integer lovelace amount as ADA with thousands
separators and 6 decimals. Local copy to avoid a Render.Single ↔
Render.Summary dependency cycle; both call sites are deterministic.
-}
formatAdaSimple :: Integer -> Text
formatAdaSimple n =
    let sign = if n < 0 then "-" else ""
        m = abs n
        whole = m `div` 1000000
        frac = m `mod` 1000000
        wholeT = withThousandsSeparators (Text.pack (show whole))
        fracT = Text.justifyRight 6 '0' (Text.pack (show frac))
     in sign <> wholeT <> "." <> fracT

withThousandsSeparators :: Text -> Text
withThousandsSeparators t =
    let chars = Text.unpack t
        len = length chars
        (head', tailGroups) = splitAt ((len - 1) `mod` 3 + 1) chars
        groups
            | null tailGroups = [head']
            | otherwise = head' : chunksOf 3 tailGroups
     in Text.pack (concatMap (\g -> if g == head' then g else "," <> g) groups)
  where
    chunksOf k xs = case splitAt k xs of
        (h, []) -> [h]
        (h, rest) -> h : chunksOf k rest

warningsSection :: DiagnosisDoc -> Text
warningsSection doc =
    let warnings = case valuePath
            (ddIntent doc)
            ["result", "intent", "warnings"] of
            Just (Array xs) -> V.toList xs
            _ -> []
        textWarnings = [s | String s <- warnings]
     in if null textWarnings
            then ""
            else
                "## Warnings\n\n"
                    <> Text.concat (map (\w -> "- " <> w <> "\n") textWarnings)
                    <> "\n"

diagramsSection :: EmittedFiles -> Text
diagramsSection files =
    let entries =
            [ ("Parties (L1)", efParties files)
            , ("Value flow (L2, Sankey TSV)", efValueFlow files)
            , ("Topology (L3)", efTopology files)
            , ("Failures (L4)", efFailures files)
            ]
        present =
            [ "- [" <> label <> "](" <> Text.pack p <> ")\n"
            | (label, Just p) <- entries
            ]
     in if null present
            then ""
            else "## Diagrams\n\n" <> Text.concat present <> "\n"

-- ---------------------------------------------------------------- --
-- Helpers
-- ---------------------------------------------------------------- --

textOf :: Text -> KeyMap.KeyMap Value -> Text -> Text
textOf k o def = case KeyMap.lookup (Key.fromText k) o of
    Just (String s) -> s
    _ -> def

textPath :: DiagnosisDoc -> [Text] -> Text -> Text
textPath doc path def =
    let v =
            valuePath
                ( -- intent paths start with "result", validate paths
                  -- start with "result"; pick intent by default since
                  -- almost every textPath consumer wants the intent
                  -- subtree.
                  ddIntent doc
                )
                path
     in case v of
            Just (String s) -> s
            _ -> fromMaybe def (Just def)

valuePath :: Value -> [Text] -> Maybe Value
valuePath = foldl' step . Just
  where
    step (Just (Object o)) k = KeyMap.lookup (Key.fromText k) o
    step _ _ = Nothing

{- | Escape a text for safe inclusion in a Markdown table cell. Pipes
become escaped pipes; literal newlines collapse to spaces.
-}
escapeTable :: Text -> Text
escapeTable =
    Text.replace "\n" " "
        . Text.replace "|" "\\|"
