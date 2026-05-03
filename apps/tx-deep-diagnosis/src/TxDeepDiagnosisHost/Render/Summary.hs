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
                    <> "| Rule | Message |\n"
                    <> "|------|---------|\n"
                    <> Text.concat (map renderFail items)
                    <> "\n"
  where
    renderFail (Object o) =
        let rule = textOf "rule" o ""
            msg = textOf "message" o ""
         in "| "
                <> escapeTable rule
                <> " | "
                <> escapeTable msg
                <> " |\n"
    renderFail _ = ""

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
