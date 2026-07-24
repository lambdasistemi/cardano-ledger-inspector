{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Conway.Inspector.Review
Description : Typed JSON vocabulary for the signer-facing tx.review result.
License     : Apache-2.0

Defines the control-category, evidence-provenance, net-signer-value,
and control-group types with deterministic JSON encoders.  Slice 1
establishes the wire contract only; projection logic lands in Slice 2.
-}
module Conway.Inspector.Review
    ( ControlCategory (..)
    , EvidenceProvenance (..)
    , NetSignerValue (..)
    , ControlGroup (..)
    , reviewVersion
    ) where

import Data.Aeson ((.=))
import Data.Aeson qualified as Aeson
import Data.Text (Text)

-- | Output control category from the signer's perspective.
data ControlCategory
    = -- | Output pays to a credential the signer controls.
      SignerControlled
    | -- | Output pays to an external verification key.
      ExternalKey
    | -- | Output is locked by a script.
      Script
    | -- | Output pays to a bootstrap (Byron) address.
      Bootstrap
    | -- | Classification is missing or unrecognized.
      Unknown
    deriving (Show, Eq)

instance Aeson.ToJSON ControlCategory where
    toJSON = \case
        SignerControlled -> Aeson.String "signer_controlled"
        ExternalKey -> Aeson.String "external_key"
        Script -> Aeson.String "script"
        Bootstrap -> Aeson.String "bootstrap"
        Unknown -> Aeson.String "unknown"

-- | Provenance tag for evidence backing a review conclusion.
data EvidenceProvenance
    = -- | Fact derived directly from the transaction body.
      LedgerProven
    | -- | Fact proven by resolved producer context.
      ContextProven
    | -- | Label decoded from a registered protocol datum.
      RegistryDecoded
    | -- | Self-declared metadata claim, never authoritative.
      MetadataClaim
    | -- | Heuristic inference (e.g. signer-change candidate).
      Heuristic
    deriving (Show, Eq)

instance Aeson.ToJSON EvidenceProvenance where
    toJSON = \case
        LedgerProven -> Aeson.String "ledger_proven"
        ContextProven -> Aeson.String "context_proven"
        RegistryDecoded -> Aeson.String "registry_decoded"
        MetadataClaim -> Aeson.String "metadata_claim"
        Heuristic -> Aeson.String "heuristic"

-- | Stable review wire-contract version string.
reviewVersion :: Text
reviewVersion = "cardano-tx-review/v1"

-- | Net signer value status for a reviewed transaction.
data NetSignerValue = NetSignerValue
    { nsvProvable :: Bool
    -- ^ True when every regular input is resolved.
    , nsvLovelace :: Maybe Text
    -- ^ Signed decimal lovelace string; Nothing when unprovable.
    , nsvNote :: Text
    -- ^ Plain-language explanation of the status.
    }
    deriving (Show, Eq)

instance Aeson.ToJSON NetSignerValue where
    toJSON (NetSignerValue provable lovelace note) =
        Aeson.object
            [ "provable" .= provable
            , "lovelace" .= lovelace
            , "note" .= note
            ]

-- | Deterministic output control group.
data ControlGroup = ControlGroup
    { cgCategory :: ControlCategory
    -- ^ Control category for every output in this group.
    , cgAddresses :: [Text]
    -- ^ Distinct addresses in the group.
    , cgOutputIndices :: [Int]
    -- ^ Zero-based transaction output indices.
    , cgOutputCount :: Int
    -- ^ Number of outputs in the group.
    , cgLovelace :: Text
    -- ^ Total lovelace as a decimal string.
    , cgAssetClassCount :: Int
    -- ^ Number of distinct non-ADA asset classes.
    , cgRole :: Text
    -- ^ Role label (e.g. continuation, order, destination).
    , cgRoleProvenance :: EvidenceProvenance
    -- ^ Provenance of the role label.
    , cgEvidence :: [EvidenceProvenance]
    -- ^ All evidence tags backing this group.
    }
    deriving (Show, Eq)

instance Aeson.ToJSON ControlGroup where
    toJSON
        (ControlGroup cat addrs idxs count lov assets role roleProv ev) =
            Aeson.object
                [ "category" .= cat
                , "addresses" .= addrs
                , "output_indices" .= idxs
                , "output_count" .= count
                , "lovelace" .= lov
                , "asset_class_count" .= assets
                , "role" .= role
                , "role_provenance" .= roleProv
                , "evidence" .= ev
                ]
