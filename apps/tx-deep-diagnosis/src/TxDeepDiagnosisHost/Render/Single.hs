{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Single
Description : Single-file markdown with all cuts embedded as fenced
              Mermaid (and Sankey-beta) blocks.

Same content as the four directory artifacts, assembled into one
self-contained document. GitHub renders Mermaid fences inline, so a
reader gets the parties / topology / failures diagrams without
opening separate files. Value flow uses @sankey-beta@ for the same
reason; it is documented as experimental but produces visibly richer
output than a TSV table when it works, and the renderer continues to
emit byte-stable text either way.

The directory-shaped renderers (parties.mmd, value-flow.tsv,
topology.mmd, failures.mmd, summary.md) are unchanged; this is an
alternative assembly that consumers can prefer.
-}
module TxDeepDiagnosisHost.Render.Single (
    renderSingleMarkdown,
) where

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (foldl')
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Vector as V

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc (..))
import TxDeepDiagnosisHost.Render.Failures (renderFailuresMermaid)
import TxDeepDiagnosisHost.Render.Names (pnLabel, resolveAddress)
import TxDeepDiagnosisHost.Render.Parties (renderPartiesMermaid)
import TxDeepDiagnosisHost.Render.Summary (
    EmittedFiles (..),
    renderSummaryMarkdown,
 )
import TxDeepDiagnosisHost.Render.Topology (renderTopologyMermaid)

{- | Render the whole explain bundle into a single markdown document.
The diagrams footer in the inlined summary is replaced with a "see
sections below" pointer rather than relative file links.
-}
renderSingleMarkdown :: ProtocolRegistry -> DiagnosisDoc -> Text
renderSingleMarkdown reg doc =
    Text.concat
        [ summaryWithoutFooter reg doc
        , partiesBlock reg doc
        , balanceBlock reg doc
        , topologyBlock reg doc
        , failuresBlock reg doc
        ]

-- | The summary minus its diagrams footer (the diagrams follow inline).
summaryWithoutFooter :: ProtocolRegistry -> DiagnosisDoc -> Text
summaryWithoutFooter reg doc =
    -- 'noFiles' suppresses the diagrams footer; the summary detects no
    -- emitted files and skips the section.
    renderSummaryMarkdown reg doc emptyFiles
  where
    emptyFiles =
        EmittedFiles
            { efParties = Nothing
            , efValueFlow = Nothing
            , efTopology = Nothing
            , efFailures = Nothing
            }

-- ---------------------------------------------------------------- --
-- Inline blocks
-- ---------------------------------------------------------------- --

partiesBlock :: ProtocolRegistry -> DiagnosisDoc -> Text
partiesBlock reg doc =
    "## Parties\n\n```mermaid\n"
        <> renderPartiesMermaid reg doc
        <> "```\n\n"

topologyBlock :: ProtocolRegistry -> DiagnosisDoc -> Text
topologyBlock reg doc =
    "## Topology\n\n```mermaid\n"
        <> renderTopologyMermaid reg doc
        <> "```\n\n"

failuresBlock :: ProtocolRegistry -> DiagnosisDoc -> Text
failuresBlock reg doc = case renderFailuresMermaid reg doc of
    Nothing -> ""
    Just t -> "## Failure overlay\n\n```mermaid\n" <> t <> "```\n\n"

{- | Balance section: two ADA-denominated tables (inputs / outputs+fee)
plus a one-line conservation check.

Sankey was tried but is misleading at this resolution: we know
aggregate input totals and aggregate bucket totals but not per-output
addresses, so any "input → output" edge in a Sankey is an
illustration, not a fact. Two side-by-side balance sheets read
cleanly, denominate large numbers in ADA so disparities don't drown
small rows, and end with the @ValueNotConservedUTxO@ delta as a
single bottom-line.
-}
balanceBlock :: ProtocolRegistry -> DiagnosisDoc -> Text
balanceBlock reg doc =
    let inputs = resolvedInputs doc
        outBuckets = outputBuckets doc
        feeLov = parseLov (feeLovelace doc)
        inTotal = sum (map (parseLov . riLovelace) inputs)
        outTotal = sum (map (parseLov . obLovelace) outBuckets) + feeLov
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
                                <> pnLabel (resolveAddress reg (riAddress ri))
                            )
                        <> " | "
                        <> formatAda (parseLov (riLovelace ri))
                        <> " |\n"
                    | (i, ri) <- zip [0 :: Int ..] inputs
                    ]
                <> "| **Total inputs** | **"
                <> formatAda inTotal
                <> "** |\n\n"
        outputsTable =
            "### Outputs + fee\n\n"
                <> "| Destination | ADA |\n"
                <> "|-------------|----:|\n"
                <> Text.concat
                    [ "| "
                        <> escapeTable
                            ( obLabel b
                                <> " bucket"
                            )
                        <> " | "
                        <> formatAda (parseLov (obLovelace b))
                        <> " |\n"
                    | b <- outBuckets
                    ]
                <> "| fee | "
                <> formatAda feeLov
                <> " |\n"
                <> "| **Total outputs + fee** | **"
                <> formatAda outTotal
                <> "** |\n\n"
        balanceLine
            | delta == 0 =
                "_Balance: inputs = outputs + fee_\n\n"
            | delta > 0 =
                "**Unaccounted: "
                    <> formatAda delta
                    <> " missing — `ValueNotConservedUTxO`**\n\n"
            | otherwise =
                "**Over-spent: "
                    <> formatAda (negate delta)
                    <> " more in outputs+fee than inputs — "
                    <> "`ValueNotConservedUTxO`**\n\n"
     in "## Balance\n\n"
            <> inputsTable
            <> outputsTable
            <> balanceLine

-- ---------------------------------------------------------------- --
-- ADA formatting
-- ---------------------------------------------------------------- --

{- | Format an integer lovelace amount as ADA with 6 decimals and
thousands separators on the whole part.
-}
formatAda :: Integer -> Text
formatAda n =
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

-- ---------------------------------------------------------------- --
-- Local copies of the parsing structs (kept here to avoid a
-- circular re-export from Render.ValueFlow / Render.Topology)
-- ---------------------------------------------------------------- --

data ResolvedInput = ResolvedInput
    { riAddress :: !Text
    , riLovelace :: !Text
    }

resolvedInputs :: DiagnosisDoc -> [ResolvedInput]
resolvedInputs doc =
    let path = ["result", "validation", "resolved_inputs"]
        items = case lookupPath (ddValidate doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in mapMaybe parseInput items
  where
    parseInput (Object o) = case KeyMap.lookup "tx_out" o of
        Just (Object txOut) -> do
            addr <- case KeyMap.lookup "address_hex" txOut of
                Just (String s) -> Just s
                _ -> Nothing
            let lov = case KeyMap.lookup "coin_lovelace" txOut of
                    Just (String s) -> s
                    _ -> "0"
            Just ResolvedInput{riAddress = addr, riLovelace = lov}
        _ -> Nothing
    parseInput _ = Nothing

data OutputBucket = OutputBucket
    { obLabel :: !Text
    , obLovelace :: !Text
    }

outputBuckets :: DiagnosisDoc -> [OutputBucket]
outputBuckets doc =
    let path = ["result", "intent", "value", "output_buckets"]
        items = case lookupPath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in mapMaybe parseBucket items
  where
    parseBucket (Object o) = do
        lab <- case KeyMap.lookup "label" o of
            Just (String s) -> Just s
            _ -> Nothing
        let lov = case KeyMap.lookup "lovelace" o of
                Just (String s) -> s
                _ -> "0"
        Just OutputBucket{obLabel = lab, obLovelace = lov}
    parseBucket _ = Nothing

-- ---------------------------------------------------------------- --
-- Helpers
-- ---------------------------------------------------------------- --

csvRow :: [Text] -> Text
csvRow xs = Text.intercalate "," (map sanitiseCsv xs) <> "\n"

-- Mermaid sankey-beta uses comma as separator; values containing a
-- comma break the row. Replace commas with U+2024 ONE DOT LEADER so
-- labels remain readable without escaping.
sanitiseCsv :: Text -> Text
sanitiseCsv = Text.replace "," "\x2024"

parseLov :: Text -> Integer
parseLov t = case reads (Text.unpack t) of
    [(n, "")] -> n
    _ -> 0

feeLovelace :: DiagnosisDoc -> Text
feeLovelace doc = case lookupPath (ddIntent doc) ["result", "intent", "fee_lovelace"] of
    Just (String s) -> s
    _ -> "0"

escapeTable :: Text -> Text
escapeTable =
    Text.replace "\n" " "
        . Text.replace "|" "\\|"

lookupPath :: Value -> [Text] -> Maybe Value
lookupPath = foldl' step . Just
  where
    step (Just (Object o)) k = KeyMap.lookup (Key.fromText k) o
    step _ _ = Nothing
