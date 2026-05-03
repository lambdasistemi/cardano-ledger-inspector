{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Summary
Description : Top-level summary.md tying the cuts together with prose.

Sections, in fixed order so the file diffs cleanly:

* Title — from @intent.title@
* Verdict paragraph — combines @summary@, @valid_for_supplied_context@,
  and the failure count
* Claims — @intent.metadata_claims@ as a table
* Effects — @intent.sections[]@ rows (already pre-rendered for display
  by the inspector library)
* Signer perspective — @intent.signing@ + signer-perspective rows
* Validation failures — one row per failure
* Warnings — @intent.warnings@
* Diagrams — relative links to whatever cuts were emitted
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
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Vector as V

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc (..))
import TxDeepDiagnosisHost.Render.Names (
    PartyName (..),
    PartySource (..),
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
        , verdictSection doc
        , observationsSection reg doc
        , scriptsSection reg doc
        , outputsSection reg doc
        , claimsSection doc
        , effectsSection doc
        , failuresSection doc
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

verdictSection :: DiagnosisDoc -> Text
verdictSection doc =
    let topSummary = ddSummary doc
        valid =
            valuePath
                (ddValidate doc)
                [ "result"
                , "validation"
                , "valid_for_supplied_context"
                ]
        verdict = case valid of
            Just (Bool True) -> "valid"
            Just (Bool False) -> "invalid"
            _ -> "unknown"
     in "## Verdict\n\n"
            <> "- "
            <> topSummary
            <> "\n"
            <> "- ledger validation: **"
            <> verdict
            <> "**\n\n"

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
        "Metadata-declared destination(s) (`self_declared`):\n\n"
            <> bulletList (map (\d -> "_" <> d <> "_") ds)
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
                    <> Text.concat (zipWith (renderScriptRow reg) [0 ..] items)
                    <> "\n"

renderScriptRow :: ProtocolRegistry -> Int -> Value -> Text
renderScriptRow _reg n v = case v of
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
                <> escapeTable det
                <> " |\n"
    renderClaim _ = ""

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
                <> rule
                <> " — "
                <> shortName predicate
                <> "\n\n"
                <> humanise predicate msg
                <> "\n"
    renderFail _ = ""

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
