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
        , valueFlowSankeyBlock reg doc
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

{- | Value-flow as a Mermaid @sankey-beta@ block. The renderer here
inlines its own logic rather than re-deriving columns from the TSV
renderer because @sankey-beta@'s row format (@source,target,value@)
differs from the TSV's four-column shape. Both are byte-deterministic
from the same envelope.

When @sum(inputs) != sum(outputs) + fee@ an explicit @(unaccounted)@
edge captures the delta so the diagram remains balanced and the
reader sees the @ValueNotConservedUTxO@ gap visually.
-}
valueFlowSankeyBlock :: ProtocolRegistry -> DiagnosisDoc -> Text
valueFlowSankeyBlock reg doc =
    let header = "## Value flow\n\n```mermaid\n---\nconfig:\n  sankey:\n    showValues: true\n---\nsankey-beta\n\n"
        body =
            mconcat
                [ inputRows reg doc
                , bucketRows doc
                , feeRow doc
                , unaccountedRow doc
                ]
        footer = "```\n\n"
     in header <> body <> footer

-- ---------------------------------------------------------------- --
-- Sankey row generation (mirrors Render.ValueFlow but emits CSV
-- triples instead of TSV quadruples)
-- ---------------------------------------------------------------- --

inputRows :: ProtocolRegistry -> DiagnosisDoc -> Text
inputRows reg doc =
    let inputs = resolvedInputs doc
     in Text.concat
            [ csvRow
                [ "input#"
                    <> Text.pack (show i)
                    <> " "
                    <> pnLabel (resolveAddress reg (riAddress ri))
                , "tx"
                , riLovelace ri
                ]
            | (i, ri) <- zip [0 :: Int ..] inputs
            ]

bucketRows :: DiagnosisDoc -> Text
bucketRows doc =
    Text.concat
        [ csvRow
            [ "tx"
            , obLabel b <> " bucket"
            , obLovelace b
            ]
        | b <- outputBuckets doc
        ]

feeRow :: DiagnosisDoc -> Text
feeRow doc = case lookupPath (ddIntent doc) ["result", "intent", "fee_lovelace"] of
    Just (String s) -> csvRow ["tx", "fee", s]
    _ -> ""

unaccountedRow :: DiagnosisDoc -> Text
unaccountedRow doc =
    let inputTotal = sum (map (parseLov . riLovelace) (resolvedInputs doc))
        outputTotal = sum (map (parseLov . obLovelace) (outputBuckets doc))
        feeTotal = case lookupPath (ddIntent doc) ["result", "intent", "fee_lovelace"] of
            Just (String s) -> parseLov s
            _ -> 0
        delta = inputTotal - (outputTotal + feeTotal)
     in if delta == 0
            then ""
            else csvRow ["tx", "(unaccounted)", Text.pack (show delta)]

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

lookupPath :: Value -> [Text] -> Maybe Value
lookupPath = foldl' step . Just
  where
    step (Just (Object o)) k = KeyMap.lookup (Key.fromText k) o
    step _ _ = Nothing
