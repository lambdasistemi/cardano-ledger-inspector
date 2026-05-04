{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.ValueFlow
Description : L2 cut — lovelace flow as Sankey-shaped TSV.

Emits a tab-separated value document with the columns
@source\\ttarget\\tlovelace\\tlabel@. Designed to be consumed by any
generic Sankey renderer (d3-sankey, observable, pivot tools); the
renderer here only assembles the table.

Flow shape until per-output address data is available in the
diagnosis envelope:

>   resolved input -- lovelace --> (tx body)
>   (tx body)       -- lovelace --> output bucket
>   (tx body)       -- lovelace --> fee
>   (tx body)       -- lovelace --> (unaccounted)   when value is not
>                                                   conserved

The unaccounted edge captures the @ValueNotConservedUTxO@ delta
honestly rather than smearing it across buckets.
-}
module TxDeepDiagnosisHost.Render.ValueFlow
    ( renderValueFlowTsv
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
import TxDeepDiagnosisHost.Render.Names
    ( PartyName (..)
    , resolveAddress
    )

-- | Render the L2 value flow as TSV.
renderValueFlowTsv :: ProtocolRegistry -> DiagnosisDoc -> Text
renderValueFlowTsv reg doc =
    let header = "source\ttarget\tlovelace\tlabel\n"
        body =
            mconcat
                [ inputRows reg doc
                , bucketRows doc
                , feeRow doc
                , unaccountedRow doc
                ]
    in  header <> body

-- ---------------------------------------------------------------- --
-- Input rows
-- ---------------------------------------------------------------- --

inputRows :: ProtocolRegistry -> DiagnosisDoc -> Text
inputRows reg doc =
    let inputs = resolvedInputs doc
        rows = zip [0 :: Int ..] inputs
    in  Text.concat (map (renderInputRow reg) rows)

renderInputRow :: ProtocolRegistry -> (Int, ResolvedInput) -> Text
renderInputRow reg (i, ri) =
    let pn = resolveAddress reg (riAddress ri)
        sourceLabel = "input#" <> Text.pack (show i) <> " " <> pnLabel pn
    in  tsvRow
            [ sourceLabel
            , "tx"
            , riLovelace ri
            , "input"
            ]

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
    in  mapMaybe parseInput items
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

-- ---------------------------------------------------------------- --
-- Output bucket rows
-- ---------------------------------------------------------------- --

bucketRows :: DiagnosisDoc -> Text
bucketRows doc =
    Text.concat (map renderBucketRow (outputBuckets doc))

renderBucketRow :: OutputBucket -> Text
renderBucketRow b =
    tsvRow
        [ "tx"
        , obLabel b <> " bucket"
        , obLovelace b
        , obLabel b <> " (" <> Text.pack (show (obCount b)) <> " outputs)"
        ]

data OutputBucket = OutputBucket
    { obLabel :: !Text
    , obCount :: !Integer
    , obLovelace :: !Text
    }

outputBuckets :: DiagnosisDoc -> [OutputBucket]
outputBuckets doc =
    let path = ["result", "intent", "value", "output_buckets"]
        items = case lookupPath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
    in  mapMaybe parseBucket items
  where
    parseBucket (Object o) = do
        lab <- case KeyMap.lookup "label" o of
            Just (String s) -> Just s
            _ -> Nothing
        let countN = case KeyMap.lookup "tx_out_count" o of
                Just (Number n) -> floor n
                _ -> 0 :: Integer
            lov = case KeyMap.lookup "lovelace" o of
                Just (String s) -> s
                _ -> "0"
        Just OutputBucket{obLabel = lab, obCount = countN, obLovelace = lov}
    parseBucket _ = Nothing

-- ---------------------------------------------------------------- --
-- Fee row
-- ---------------------------------------------------------------- --

feeRow :: DiagnosisDoc -> Text
feeRow doc = case lookupPath (ddIntent doc) ["result", "intent", "fee_lovelace"] of
    Just (String s) -> tsvRow ["tx", "fee", s, "fee paid"]
    _ -> ""

-- ---------------------------------------------------------------- --
-- Unaccounted row (ValueNotConserved delta)
-- ---------------------------------------------------------------- --

unaccountedRow :: DiagnosisDoc -> Text
unaccountedRow doc =
    let inputTotal = sumInputs doc
        outputTotal = sumOutputs doc
        feeTotal = parseLovelace (feeOf doc)
        delta = inputTotal - (outputTotal + feeTotal)
    in  if delta == 0
            then ""
            else
                tsvRow
                    [ "tx"
                    , "(unaccounted)"
                    , Text.pack (show delta)
                    , "input total - (output total + fee); "
                        <> "non-zero implies ValueNotConservedUTxO"
                    ]

sumInputs :: DiagnosisDoc -> Integer
sumInputs =
    foldl' (\acc ri -> acc + parseLovelace (riLovelace ri)) 0
        . resolvedInputs

sumOutputs :: DiagnosisDoc -> Integer
sumOutputs =
    foldl' (\acc b -> acc + parseLovelace (obLovelace b)) 0
        . outputBuckets

feeOf :: DiagnosisDoc -> Text
feeOf doc = case lookupPath (ddIntent doc) ["result", "intent", "fee_lovelace"] of
    Just (String s) -> s
    _ -> "0"

parseLovelace :: Text -> Integer
parseLovelace t = case reads (Text.unpack t) of
    [(n, "")] -> n
    _ -> 0

-- ---------------------------------------------------------------- --
-- Helpers
-- ---------------------------------------------------------------- --

tsvRow :: [Text] -> Text
tsvRow xs = Text.intercalate "\t" xs <> "\n"

lookupPath :: Value -> [Text] -> Maybe Value
lookupPath = foldl' step . Just
  where
    step (Just (Object o)) k = KeyMap.lookup (Key.fromText k) o
    step _ _ = Nothing
