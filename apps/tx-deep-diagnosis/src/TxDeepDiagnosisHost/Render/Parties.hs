{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Parties
Description : L1 cut — distinct parties involved in the transaction.

Renders a Mermaid @flowchart LR@ with one node per distinct party.
A party is one of:

* a resolved input — labelled by the input address
* an output bucket — labelled by bucket name (external_key / script /
  signer_controlled etc.) and aggregate lovelace
* a declared required signer — labelled by hash

The diagram answers "who is moving what to whom" without the full
topology. The body is a single central @tx@ node; consumed-by /
produces / required edges connect parties to it.
-}
module TxDeepDiagnosisHost.Render.Parties (
    renderPartiesMermaid,
) where

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (foldl', nub)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Builder as TB
import qualified Data.Vector as V

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc (..))
import TxDeepDiagnosisHost.Render.Names (
    PartyName (..),
    PartySource (..),
    resolveAddress,
    truncateHash,
 )

-- | Render the L1 parties cut as a Mermaid @flowchart LR@ document.
renderPartiesMermaid :: ProtocolRegistry -> DiagnosisDoc -> Text
renderPartiesMermaid reg doc =
    TL.toStrict
        . TB.toLazyText
        . mconcat
        $ [ "%% L1 — parties involved in tx "
          , txt (txIdOf doc)
          , "\n"
          , "flowchart LR\n"
          , "    classDef signer fill:#fff8dc,stroke:#cc9900,stroke-width:2px\n"
          , "    classDef inputAddr fill:#f0f0f0,stroke:#666\n"
          , "    classDef bucket fill:#e6f0ff,stroke:#3366cc\n"
          , "    classDef txBody fill:#fffefa,stroke:#000,stroke-width:2px\n"
          , "    tx[\"tx\"]:::txBody\n"
          , inputBlock reg doc
          , bucketBlock doc
          , signerBlock reg doc
          ]

-- ---------------------------------------------------------------- --
-- Input parties
-- ---------------------------------------------------------------- --

inputBlock :: ProtocolRegistry -> DiagnosisDoc -> TB.Builder
inputBlock reg doc =
    let addrs = nub (resolvedInputAddresses doc)
        rows = zip [0 :: Int ..] addrs
     in mconcat (map (renderInput reg) rows)

renderInput :: ProtocolRegistry -> (Int, Text) -> TB.Builder
renderInput reg (i, addr) =
    let pn = resolveAddress reg addr
        tag = "I" <> txt (Text.pack (show i))
     in mconcat
            [ "    "
            , tag
            , "[\""
            , txt (escape (renderPartyLabel pn))
            , "\"]:::inputAddr\n    "
            , tag
            , " -- consumed --> tx\n"
            ]

resolvedInputAddresses :: DiagnosisDoc -> [Text]
resolvedInputAddresses doc =
    let validate = ddValidate doc
        validation = lookupPath validate ["result", "validation"]
        resolved = case validation of
            Just (Object o) -> case KeyMap.lookup "resolved_inputs" o of
                Just (Array xs) -> V.toList xs
                _ -> []
            _ -> []
     in mapMaybe addressOfResolved resolved

addressOfResolved :: Value -> Maybe Text
addressOfResolved v = case v of
    Object o -> case KeyMap.lookup "tx_out" o of
        Just (Object txOut) -> case KeyMap.lookup "address_hex" txOut of
            Just (String s) -> Just s
            _ -> Nothing
        _ -> Nothing
    _ -> Nothing

-- ---------------------------------------------------------------- --
-- Output bucket parties
-- ---------------------------------------------------------------- --

bucketBlock :: DiagnosisDoc -> TB.Builder
bucketBlock doc =
    let buckets = outputBuckets doc
        rows = zip [0 :: Int ..] buckets
     in mconcat (map renderBucket rows)

renderBucket :: (Int, OutputBucket) -> TB.Builder
renderBucket (i, b) =
    let tag = "O" <> txt (Text.pack (show i))
        label =
            obLabel b
                <> " ("
                <> Text.pack (show (obCount b))
                <> " out, "
                <> obLovelace b
                <> " lovelace)"
     in mconcat
            [ "    "
            , tag
            , "[\""
            , txt (escape label)
            , "\"]:::bucket\n    tx -- produces --> "
            , tag
            , "\n"
            ]

data OutputBucket = OutputBucket
    { obLabel :: !Text
    , obCount :: !Integer
    , obLovelace :: !Text
    }

outputBuckets :: DiagnosisDoc -> [OutputBucket]
outputBuckets doc =
    let intent = ddIntent doc
        bucketsArr =
            lookupPath intent ["result", "intent", "value", "output_buckets"]
        items = case bucketsArr of
            Just (Array xs) -> V.toList xs
            _ -> []
     in mapMaybe parseBucket items
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
-- Required signer parties
-- ---------------------------------------------------------------- --

signerBlock :: ProtocolRegistry -> DiagnosisDoc -> TB.Builder
signerBlock _reg doc =
    let hashes = nub (declaredSignerHashes doc)
        rows = zip [0 :: Int ..] hashes
     in mconcat (map renderSigner rows)

renderSigner :: (Int, Text) -> TB.Builder
renderSigner (i, h) =
    let tag = "S" <> txt (Text.pack (show i))
        label = "signer " <> truncateHash h
     in mconcat
            [ "    "
            , tag
            , "[\""
            , txt (escape label)
            , "\"]:::signer\n    "
            , tag
            , " -. required .-> tx\n"
            ]

declaredSignerHashes :: DiagnosisDoc -> [Text]
declaredSignerHashes doc =
    let intent = ddIntent doc
        sigs =
            lookupPath
                intent
                [ "result"
                , "intent"
                , "signing"
                , "missing_vkey_witnesses"
                ]
        items = case sigs of
            Just (Array xs) -> V.toList xs
            _ -> []
     in mapMaybe extractHash items
  where
    extractHash (Object o) = case KeyMap.lookup "hash" o of
        Just (String s) -> Just s
        _ -> Nothing
    extractHash _ = Nothing

-- ---------------------------------------------------------------- --
-- Helpers
-- ---------------------------------------------------------------- --

txIdOf :: DiagnosisDoc -> Text
txIdOf doc = case lookupPath (ddIntent doc) ["result", "intent", "tx_id"] of
    Just (String s) -> s
    _ -> ""

renderPartyLabel :: PartyName -> Text
renderPartyLabel pn = case pnSource pn of
    TruncatedHex -> pnLabel pn
    _ -> pnLabel pn

lookupPath :: Value -> [Text] -> Maybe Value
lookupPath = foldl' step . Just
  where
    step (Just (Object o)) k = KeyMap.lookup (Key.fromText k) o
    step _ _ = Nothing

txt :: Text -> TB.Builder
txt = TB.fromText

escape :: Text -> Text
escape = Text.replace "\"" "\\\""
