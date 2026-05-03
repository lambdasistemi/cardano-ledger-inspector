{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Topology
Description : L3 cut — full transaction topology as a Mermaid flowchart.

One node per resolved input, output bucket, reference input,
collateral input/return, body, and synthetic signer. Validation
failures are overlaid as Mermaid 'classDef' classes on the affected
nodes (mapping in 'TxDeepDiagnosisHost.Render.Failures').

Per-output topology (one node per output, not per bucket) requires
output address data that the diagnosis envelope does not currently
expose; bucket aggregates are used until the inspector library
surfaces per-output addresses.
-}
module TxDeepDiagnosisHost.Render.Topology (
    renderTopologyMermaid,
) where

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (foldl', nub)
import Data.Maybe (mapMaybe)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Builder as TB
import qualified Data.Vector as V

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc (..))
import TxDeepDiagnosisHost.Render.Names (
    PartyName (..),
    resolveAddress,
    truncateHash,
 )

-- | Render the L3 topology cut.
renderTopologyMermaid :: ProtocolRegistry -> DiagnosisDoc -> Text
renderTopologyMermaid reg doc =
    TL.toStrict
        . TB.toLazyText
        . mconcat
        $ [ "%% L3 — full topology for tx "
          , txt (txIdOf doc)
          , "\n"
          , "flowchart TD\n"
          , "    classDef body fill:#fffefa,stroke:#000,stroke-width:2px\n"
          , "    classDef bodyFail fill:#ffe6e6,stroke:#cc0000,stroke-width:2px\n"
          , "    classDef inputNode fill:#f0f0f0,stroke:#666\n"
          , "    classDef inputFail fill:#ffe6e6,stroke:#cc0000\n"
          , "    classDef refInput fill:#f8f8f0,stroke:#999,stroke-dasharray:4 4\n"
          , "    classDef collateral fill:#fff0f0,stroke:#aa6666\n"
          , "    classDef bucket fill:#e6f0ff,stroke:#3366cc\n"
          , "    classDef signer fill:#fff8dc,stroke:#cc9900\n"
          , "    classDef signerFail fill:#ffe6e6,stroke:#cc0000,stroke-width:2px\n"
          , bodyNode bodyFailing doc
          , inputBlock reg doc
          , bucketBlock doc
          , refInputBlock reg doc
          , collateralBlock doc
          , signerBlock signerFailingHashes doc
          ]
  where
    failureClasses = classifyFailures doc
    bodyFailing = fcBodyFail failureClasses
    signerFailingHashes = fcSignerFailHashes failureClasses

-- ---------------------------------------------------------------- --
-- Body
-- ---------------------------------------------------------------- --

bodyNode :: Bool -> DiagnosisDoc -> TB.Builder
bodyNode failing doc =
    let cls = if failing then "bodyFail" else "body"
        annotations = bodyAnnotations doc
        label = "tx body\\n" <> Text.intercalate "\\n" annotations
     in mconcat
            [ "    body[\""
            , txt (escape label)
            , "\"]:::"
            , txt cls
            , "\n"
            ]

bodyAnnotations :: DiagnosisDoc -> [Text]
bodyAnnotations doc =
    let intent = ddIntent doc
        feeT = case lookupPath intent ["result", "intent", "fee_lovelace"] of
            Just (String s) -> "fee " <> s <> " lovelace"
            _ -> "fee unknown"
        features =
            lookupPath intent ["result", "intent", "features"]
        feat k =
            case features of
                Just (Object o) -> case KeyMap.lookup (Key.fromText k) o of
                    Just (Number n) -> Just (floor n :: Integer)
                    _ -> Nothing
                _ -> Nothing
        redeemers = maybe "redeemers ?" (\n -> "redeemers " <> Text.pack (show n)) (feat "redeemer_count")
        withdrawals =
            maybe
                "withdrawals ?"
                (\n -> "withdrawals " <> Text.pack (show n))
                (feat "withdrawal_count")
        mintBurn =
            case (feat "minted_asset_count", feat "burned_asset_count") of
                (Just 0, Just 0) -> "no mint/burn"
                (Just m, Just b) ->
                    "mint " <> Text.pack (show m) <> " / burn " <> Text.pack (show b)
                _ -> "mint/burn ?"
        collateralFlag =
            case feat "collateral_input_count" of
                Just 0 -> "no collateral"
                Just n -> "collateral " <> Text.pack (show n)
                Nothing -> "collateral ?"
     in [feeT, redeemers, withdrawals, mintBurn, collateralFlag]

-- ---------------------------------------------------------------- --
-- Inputs
-- ---------------------------------------------------------------- --

inputBlock :: ProtocolRegistry -> DiagnosisDoc -> TB.Builder
inputBlock reg doc =
    let inputs = resolvedInputs doc
        rows = zip [0 :: Int ..] inputs
     in mconcat (map (renderInput reg) rows)

renderInput :: ProtocolRegistry -> (Int, ResolvedInput) -> TB.Builder
renderInput reg (i, ri) =
    let pn = resolveAddress reg (riAddress ri)
        tag = "in" <> txt (Text.pack (show i))
        label =
            "input #"
                <> Text.pack (show i)
                <> "\\n"
                <> pnLabel pn
                <> "\\n"
                <> riLovelace ri
                <> " lovelace"
     in mconcat
            [ "    "
            , tag
            , "[\""
            , txt (escape label)
            , "\"]:::inputNode\n    "
            , tag
            , " --> body\n"
            ]

data ResolvedInput = ResolvedInput
    { riAddress :: !Text
    , riLovelace :: !Text
    }

resolvedInputs :: DiagnosisDoc -> [ResolvedInput]
resolvedInputs doc =
    parseResolvedList (ddValidate doc) ["result", "validation", "resolved_inputs"]

resolvedReferenceInputs :: DiagnosisDoc -> [ResolvedInput]
resolvedReferenceInputs doc =
    parseResolvedList
        (ddValidate doc)
        ["result", "validation", "resolved_reference_inputs"]

parseResolvedList :: Value -> [Text] -> [ResolvedInput]
parseResolvedList v path =
    let items = case lookupPath v path of
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

-- ---------------------------------------------------------------- --
-- Output buckets (until per-output addresses are exposed)
-- ---------------------------------------------------------------- --

bucketBlock :: DiagnosisDoc -> TB.Builder
bucketBlock doc =
    mconcat (map renderBucket (zip [0 :: Int ..] (outputBuckets doc)))

renderBucket :: (Int, OutputBucket) -> TB.Builder
renderBucket (i, b) =
    let tag = "out" <> txt (Text.pack (show i))
        label =
            obLabel b
                <> " bucket\\n"
                <> Text.pack (show (obCount b))
                <> " outputs / "
                <> obLovelace b
                <> " lovelace"
     in mconcat
            [ "    "
            , tag
            , "[\""
            , txt (escape label)
            , "\"]:::bucket\n    body --> "
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
    let items =
            case lookupPath
                (ddIntent doc)
                ["result", "intent", "value", "output_buckets"] of
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
-- Reference inputs
-- ---------------------------------------------------------------- --

refInputBlock :: ProtocolRegistry -> DiagnosisDoc -> TB.Builder
refInputBlock reg doc =
    mconcat (map (renderRef reg) (zip [0 :: Int ..] (resolvedReferenceInputs doc)))

renderRef :: ProtocolRegistry -> (Int, ResolvedInput) -> TB.Builder
renderRef reg (i, ri) =
    let pn = resolveAddress reg (riAddress ri)
        tag = "ref" <> txt (Text.pack (show i))
        label =
            "ref #"
                <> Text.pack (show i)
                <> "\\n"
                <> pnLabel pn
     in mconcat
            [ "    "
            , tag
            , "[\""
            , txt (escape label)
            , "\"]:::refInput\n    "
            , tag
            , " -. read .-> body\n"
            ]

-- ---------------------------------------------------------------- --
-- Collateral
-- ---------------------------------------------------------------- --

collateralBlock :: DiagnosisDoc -> TB.Builder
collateralBlock doc =
    let intent = ddIntent doc
        feat k = case lookupPath intent ["result", "intent", "features"] of
            Just (Object o) -> case KeyMap.lookup (Key.fromText k) o of
                Just (Bool b) -> Just b
                Just (Number n) -> Just (n /= 0)
                _ -> Nothing
            _ -> Nothing
        hasCollIn = feat "collateral_input_count" == Just True
        hasReturn = feat "has_collateral_return" == Just True
        block =
            (if hasCollIn then "    coll[\"collateral input\"]:::collateral\n    coll -. fee guard .-> body\n" else "")
                <> (if hasReturn then "    collret[\"collateral return\"]:::collateral\n    body -. on script fail .-> collret\n" else "")
     in TB.fromText block

-- ---------------------------------------------------------------- --
-- Signers
-- ---------------------------------------------------------------- --

signerBlock :: Set Text -> DiagnosisDoc -> TB.Builder
signerBlock failing doc =
    mconcat
        ( map
            (renderSigner failing)
            (zip [0 :: Int ..] (nub (declaredSignerHashes doc)))
        )

renderSigner :: Set Text -> (Int, Text) -> TB.Builder
renderSigner failing (i, h) =
    let tag = "sig" <> txt (Text.pack (show i))
        label = "signer " <> truncateHash h
        cls =
            if Set.member h failing
                then "signerFail"
                else "signer"
     in mconcat
            [ "    "
            , tag
            , "[\""
            , txt (escape label)
            , "\"]:::"
            , txt cls
            , "\n    "
            , tag
            , " -. required .-> body\n"
            ]

declaredSignerHashes :: DiagnosisDoc -> [Text]
declaredSignerHashes doc =
    let path =
            [ "result"
            , "intent"
            , "signing"
            , "missing_vkey_witnesses"
            ]
        items = case lookupPath (ddIntent doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in mapMaybe extractHash items
  where
    extractHash (Object o) = case KeyMap.lookup "hash" o of
        Just (String s) -> Just s
        _ -> Nothing
    extractHash _ = Nothing

-- ---------------------------------------------------------------- --
-- Failure classification
-- ---------------------------------------------------------------- --

data FailureClasses = FailureClasses
    { fcBodyFail :: !Bool
    , fcSignerFailHashes :: !(Set Text)
    }

classifyFailures :: DiagnosisDoc -> FailureClasses
classifyFailures doc =
    let items = case lookupPath
            (ddValidate doc)
            ["result", "validation", "failures"] of
            Just (Array xs) -> V.toList xs
            _ -> []
        classify acc (Object o) =
            let predicate = case KeyMap.lookup "predicate" o of
                    Just (String s) -> s
                    _ -> ""
                msg = case KeyMap.lookup "message" o of
                    Just (String s) -> s
                    _ -> ""
                blob = predicate <> " " <> msg
                isMissingWit = "MissingVKeyWitnesses" `Text.isInfixOf` blob
                hashesIn =
                    if isMissingWit
                        then extractHashesFromMessage blob
                        else Set.empty
             in FailureClasses
                    { fcBodyFail = fcBodyFail acc || not isMissingWit
                    , fcSignerFailHashes =
                        Set.union (fcSignerFailHashes acc) hashesIn
                    }
        classify acc _ = acc
     in foldl' classify FailureClasses{fcBodyFail = False, fcSignerFailHashes = Set.empty} items

extractHashesFromMessage :: Text -> Set Text
extractHashesFromMessage =
    Set.fromList
        . filter isHashLike
        . map cleanup
        . Text.splitOn "KeyHash"
  where
    cleanup t =
        Text.takeWhile (/= '"') (Text.drop 1 (Text.dropWhile (/= '"') t))
    isHashLike t = Text.length t == 56 && Text.all isHex t
    isHex c = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')

-- ---------------------------------------------------------------- --
-- Helpers
-- ---------------------------------------------------------------- --

txIdOf :: DiagnosisDoc -> Text
txIdOf doc = case lookupPath (ddIntent doc) ["result", "intent", "tx_id"] of
    Just (String s) -> s
    _ -> ""

lookupPath :: Value -> [Text] -> Maybe Value
lookupPath = foldl' step . Just
  where
    step (Just (Object o)) k = KeyMap.lookup (Key.fromText k) o
    step _ _ = Nothing

txt :: Text -> TB.Builder
txt = TB.fromText

escape :: Text -> Text
escape = Text.replace "\"" "\\\""
