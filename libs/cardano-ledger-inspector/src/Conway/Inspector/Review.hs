{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Conway.Inspector.Review
Description : Typed JSON vocabulary and pure projection for the signer-facing tx.review result.
License     : Apache-2.0

Defines the control-category, evidence-provenance, net-signer-value,
and control-group vocabulary together with the versioned review result
and a pure projection from the shared, locally enriched @tx.intent@
response into that result.

The projection is target-independent. It reads structured fields from
the enriched intent value (output rows, buckets, signer net status,
withdrawals, claims, context coverage) plus a few structured body facts
the intent result does not expose (total collateral and collateral
return, supplied by the caller). It never parses the human-readable
@metrics@, @effects@, or @sections@ prose.
-}
module Conway.Inspector.Review
    ( ControlCategory (..)
    , EvidenceProvenance (..)
    , NetSignerValue (..)
    , ControlGroup (..)
    , ReviewContext (..)
    , ReviewFee (..)
    , ReviewCollateral (..)
    , ReviewSource (..)
    , ReviewClaim (..)
    , ReviewResult (..)
    , reviewVersion
    , projectReview
    ) where

import Data.Aeson ((.=))
import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Foldable qualified as Foldable
import Data.List (maximumBy, nub, sort, sortBy)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust, mapMaybe)
import Data.Ord (Down (Down), comparing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T
import Text.Read (readMaybe)

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
    deriving (Show, Eq, Ord)

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

-- | Input-resolution context for a reviewed transaction.
data ReviewContext = ReviewContext
    { rcInputStatus :: Text
    -- ^ @"complete"@ when every regular input resolves, else @"incomplete"@.
    , rcRegularInputCount :: Int
    -- ^ Number of regular transaction inputs.
    , rcResolvedRegularInputCount :: Int
    -- ^ Regular inputs resolved from explicit producer context.
    , rcMissingRegularInputCount :: Int
    -- ^ Regular inputs with no resolved producer output.
    }
    deriving (Show, Eq)

instance Aeson.ToJSON ReviewContext where
    toJSON (ReviewContext status regular resolved missing) =
        Aeson.object
            [ "input_status" .= status
            , "regular_input_count" .= regular
            , "resolved_regular_input_count" .= resolved
            , "missing_regular_input_count" .= missing
            ]

-- | Transaction fee.
newtype ReviewFee = ReviewFee
    { rfLovelace :: Text
    -- ^ Fee in lovelace as a decimal string.
    }
    deriving (Show, Eq)

instance Aeson.ToJSON ReviewFee where
    toJSON (ReviewFee lovelace) =
        Aeson.object ["lovelace" .= lovelace]

-- | Conditional collateral accounting, separate from regular outputs.
data ReviewCollateral = ReviewCollateral
    { rcpConditional :: Bool
    -- ^ True when the transaction declares collateral inputs.
    , rcpInputCount :: Int
    -- ^ Number of declared collateral inputs.
    , rcpBodyTotalLovelace :: Text
    -- ^ Body-declared total collateral as a decimal string.
    , rcpReturnLovelace :: Maybe Text
    -- ^ Collateral return value as a decimal string, if any.
    }
    deriving (Show, Eq)

instance Aeson.ToJSON ReviewCollateral where
    toJSON (ReviewCollateral conditional count bodyTotal returnLov) =
        Aeson.object
            [ "conditional" .= conditional
            , "input_count" .= count
            , "body_total_lovelace" .= bodyTotal
            , "return_lovelace" .= returnLov
            ]

-- | A value source, kept separate by kind.
data ReviewSource
    = -- | Regular transaction inputs and their resolution coverage.
      RegularInputSource
        { risCount :: Int
        , risResolvedCount :: Int
        , risMissingCount :: Int
        , risResolvedLovelace :: Text
        }
    | -- | Withdrawals, with the total withdrawn lovelace.
      WithdrawalSource
        { wsCount :: Int
        , wsLovelace :: Text
        }
    | -- | Conditional collateral, separate from regular outputs.
      CollateralSource
        { csConditional :: Bool
        , csInputCount :: Int
        , csBodyTotalLovelace :: Text
        , csReturnLovelace :: Maybe Text
        }
    | -- | Read-only reference inputs.
      ReferenceInputSource
        { refsReadOnly :: Bool
        , refsCount :: Int
        }
    deriving (Show, Eq)

instance Aeson.ToJSON ReviewSource where
    toJSON = \case
        RegularInputSource count resolved missing resolvedLov ->
            Aeson.object
                [ "kind" .= ("regular_input" :: Text)
                , "count" .= count
                , "resolved_count" .= resolved
                , "missing_count" .= missing
                , "resolved_lovelace" .= resolvedLov
                ]
        WithdrawalSource count lovelace ->
            Aeson.object
                [ "kind" .= ("withdrawal" :: Text)
                , "count" .= count
                , "lovelace" .= lovelace
                ]
        CollateralSource conditional count bodyTotal returnLov ->
            Aeson.object
                [ "kind" .= ("collateral" :: Text)
                , "conditional" .= conditional
                , "input_count" .= count
                , "body_total_lovelace" .= bodyTotal
                , "return_lovelace" .= returnLov
                ]
        ReferenceInputSource readOnly count ->
            Aeson.object
                [ "kind" .= ("reference_input" :: Text)
                , "read_only" .= readOnly
                , "count" .= count
                ]

-- | Isolated self-declared metadata claim.
data ReviewClaim = ReviewClaim
    { rclLabel :: Text
    -- ^ Claim label.
    , rclValue :: Text
    -- ^ Claim value.
    , rclDetail :: Text
    -- ^ Claim detail.
    , rclProvenance :: EvidenceProvenance
    -- ^ Always 'MetadataClaim'.
    , rclSelfDeclared :: Bool
    -- ^ Always True; claims are never independently verified.
    }
    deriving (Show, Eq)

instance Aeson.ToJSON ReviewClaim where
    toJSON (ReviewClaim label value detail provenance selfDeclared) =
        Aeson.object
            [ "label" .= label
            , "value" .= value
            , "detail" .= detail
            , "provenance" .= provenance
            , "self_declared" .= selfDeclared
            ]

-- | Versioned signer-facing transaction review result.
data ReviewResult = ReviewResult
    { rrVersion :: Text
    , rrTxId :: Text
    , rrBodyHash :: Text
    , rrContext :: ReviewContext
    , rrSources :: [ReviewSource]
    , rrControlGroups :: [ControlGroup]
    , rrHighValueMovements :: [ControlGroup]
    , rrFee :: ReviewFee
    , rrCollateral :: ReviewCollateral
    , rrNetSignerValue :: NetSignerValue
    , rrClaims :: [ReviewClaim]
    , rrWarnings :: [Text]
    }
    deriving (Show, Eq)

instance Aeson.ToJSON ReviewResult where
    toJSON rr =
        Aeson.object
            [ "version" .= rrVersion rr
            , "tx_id" .= rrTxId rr
            , "body_hash" .= rrBodyHash rr
            , "context" .= rrContext rr
            , "sources" .= rrSources rr
            , "control_groups" .= rrControlGroups rr
            , "high_value_movements" .= rrHighValueMovements rr
            , "fee" .= rrFee rr
            , "collateral" .= rrCollateral rr
            , "net_signer_value" .= rrNetSignerValue rr
            , "claims" .= rrClaims rr
            , "warnings" .= rrWarnings rr
            ]

{- | Project the shared, locally enriched @tx.intent@ result into the
versioned signer-review result.

The first argument is the set of fully serialized address hexes for
regular inputs resolved from explicit producer context; it backs the
context-proven same-address continuation role. The next two arguments
are the body-declared total collateral and the collateral return value,
structured body facts the intent result does not expose. The final
argument is the enriched @result.intent@ object.
-}
projectReview
    :: Set.Set Text
    -> Maybe Integer
    -> Maybe Integer
    -> Aeson.Value
    -> ReviewResult
projectReview resolvedAddrs totalCollateral collateralReturn intent =
    ReviewResult
        { rrVersion = reviewVersion
        , rrTxId = fromMaybe "" (textAt "tx_id" intent)
        , rrBodyHash = fromMaybe "" (textAt "body_hash" intent)
        , rrContext = context
        , rrSources = sources
        , rrControlGroups = groups
        , rrHighValueMovements = highValue
        , rrFee = ReviewFee feeLovelace
        , rrCollateral = collateral
        , rrNetSignerValue = net
        , rrClaims = claims
        , rrWarnings = warnings
        }
  where
    valueObj = fromMaybe Aeson.Null (lookupKey "value" intent)
    contextObj = fromMaybe Aeson.Null (lookupKey "context" intent)
    featuresObj = fromMaybe Aeson.Null (lookupKey "features" intent)
    signerLovObj =
        fromMaybe Aeson.Null (lookupKey "signer_lovelace" valueObj)

    inputCount = fromMaybe 0 (intAt "input_count" contextObj)
    resolvedCount = fromMaybe 0 (intAt "resolved_input_count" contextObj)
    missingCount = fromMaybe 0 (intAt "missing_input_count" contextObj)
    referenceInputCount =
        fromMaybe 0 (intAt "reference_input_count" contextObj)
    collateralInputCount =
        fromMaybe 0 (intAt "collateral_input_count" featuresObj)

    context =
        ReviewContext
            { rcInputStatus =
                if missingCount == 0 then "complete" else "incomplete"
            , rcRegularInputCount = inputCount
            , rcResolvedRegularInputCount = resolvedCount
            , rcMissingRegularInputCount = missingCount
            }

    outputs = mapMaybe parseOutput (arrayAt "outputs" valueObj)
    groups = buildGroups outputs
    totalOutputLovelace = sum (map ofLovelace outputs)
    highValue = selectHighValue groups totalOutputLovelace

    feeLovelace = fromMaybe "0" (textAt "fee_lovelace" intent)

    bodyTotalLovelace =
        maybe "0" (T.pack . show) totalCollateral
    returnLovelace =
        fmap (T.pack . show) collateralReturn
    collateral =
        ReviewCollateral
            { rcpConditional = collateralInputCount > 0
            , rcpInputCount = collateralInputCount
            , rcpBodyTotalLovelace = bodyTotalLovelace
            , rcpReturnLovelace = returnLovelace
            }

    withdrawalRows = arrayAt "withdrawals" intent
    withdrawalTotal =
        T.pack . show . sum $
            mapMaybe (integerTextAt "amount_lovelace") withdrawalRows

    resolvedInputLovelace =
        fromMaybe "0" (textAt "resolved_input_lovelace" valueObj)

    sources =
        [ RegularInputSource
            inputCount
            resolvedCount
            missingCount
            resolvedInputLovelace
        , WithdrawalSource
            (length withdrawalRows)
            withdrawalTotal
        , CollateralSource
            (collateralInputCount > 0)
            collateralInputCount
            bodyTotalLovelace
            returnLovelace
        , ReferenceInputSource True referenceInputCount
        ]

    provable = fromMaybe False (boolAt "net_spend_known" valueObj)
    net =
        NetSignerValue
            { nsvProvable = provable
            , nsvLovelace =
                if provable
                    then textAt "net_lovelace" signerLovObj
                    else Nothing
            , nsvNote =
                if provable
                    then
                        "all regular inputs resolved; net signer gain/loss proven from explicit producer context"
                    else
                        "missing input context, net signer gain/loss unprovable"
            }

    claims = mapMaybe parseClaim (arrayAt "claims" intent)
    warnings = mapMaybe asText (arrayAt "warnings" intent)

    buildGroups outs =
        let entries =
                map
                    ( \opf ->
                        ( groupKey opf
                        , GroupAcc
                            (ofCategory opf)
                            (ofAddressHex opf)
                            [ofIndex opf]
                            (ofLovelace opf)
                            (ofAssetKeys opf)
                            (riRole (outputRole opf))
                            (riProvenance (outputRole opf))
                            (riEvidence (outputRole opf))
                        )
                    )
                    outs
            grouped =
                Map.fromListWith combineAcc entries
        in  sortBy
                (comparing groupMinIndex)
                (map accToGroup (Map.elems grouped))
      where
        groupKey opf =
            ( categoryToText (ofCategory opf)
            , ofAddressHex opf
            , riRole (outputRole opf)
            )
        outputRole = outputRoleFor resolvedAddrs

    combineAcc new existing =
        existing
            { gaIndices = gaIndices new <> gaIndices existing
            , gaLovelace = gaLovelace existing + gaLovelace new
            , gaAssetKeys = gaAssetKeys existing <> gaAssetKeys new
            }

    groupMinIndex group = minimum (cgOutputIndices group)

-- | Parsed structured facts for one intent output row.
data OutputFacts = OutputFacts
    { ofIndex :: Int
    , ofCategory :: ControlCategory
    , ofAddressHex :: Text
    , ofLovelace :: Integer
    , ofAssetKeys :: Set.Set (Text, Text)
    , ofRegistryLabel :: Maybe Text
    }

parseOutput :: Aeson.Value -> Maybe OutputFacts
parseOutput v = do
    ix <- intAt "index" v
    bucket <- textAt "bucket" v
    addr <- textAt "address_hex" v
    lov <- integerTextAt "coin_lovelace" v
    pure
        OutputFacts
            { ofIndex = ix
            , ofCategory = bucketToCategory bucket
            , ofAddressHex = addr
            , ofLovelace = lov
            , ofAssetKeys = outputAssetKeys (lookupKey "assets" v)
            , ofRegistryLabel = lookupKey "decoded_datum" v >>= textAt "label"
            }

outputAssetKeys :: Maybe Aeson.Value -> Set.Set (Text, Text)
outputAssetKeys (Just (Aeson.Object policies)) =
    Set.fromList
        [ (AesonKey.toText policyId, AesonKey.toText assetName)
        | (policyId, Aeson.Object names) <- KeyMap.toList policies
        , (assetName, _) <- KeyMap.toList names
        ]
outputAssetKeys _ = Set.empty

-- | Role selection result for one output.
data RoleInfo = RoleInfo
    { riRole :: Text
    , riProvenance :: EvidenceProvenance
    , riEvidence :: [EvidenceProvenance]
    }

{- | Select the authoritative role for one output.

Authority descends from a context-proven same-address continuation, to a
registry-decoded protocol label, to a heuristic signer return/change
candidate, to a generic ledger-proven role. Metadata never selects a
role.
-}
outputRoleFor :: Set.Set Text -> OutputFacts -> RoleInfo
outputRoleFor resolvedAddrs opf
    | isContinuation =
        RoleInfo
            { riRole = fromMaybe "continuation" registryLabel
            , riProvenance = ContextProven
            , riEvidence =
                [LedgerProven, ContextProven]
                    <> [RegistryDecoded | isJust registryLabel]
            }
    | isJust registryLabel =
        RoleInfo
            { riRole = fromMaybe "" registryLabel
            , riProvenance = RegistryDecoded
            , riEvidence = [LedgerProven, RegistryDecoded]
            }
    | ofCategory opf == SignerControlled =
        RoleInfo
            { riRole = "signer_change"
            , riProvenance = Heuristic
            , riEvidence = [LedgerProven, Heuristic]
            }
    | otherwise =
        RoleInfo
            { riRole = genericRole (ofCategory opf)
            , riProvenance = LedgerProven
            , riEvidence = [LedgerProven]
            }
  where
    isContinuation = ofAddressHex opf `Set.member` resolvedAddrs
    registryLabel = ofRegistryLabel opf

genericRole :: ControlCategory -> Text
genericRole = \case
    SignerControlled -> "signer_change"
    ExternalKey -> "external_key_destination"
    Script -> "script_lock"
    Bootstrap -> "bootstrap"
    Unknown -> "unknown"

bucketToCategory :: Text -> ControlCategory
bucketToCategory = \case
    "signer_controlled" -> SignerControlled
    "external_key" -> ExternalKey
    "script" -> Script
    "bootstrap" -> Bootstrap
    _ -> Unknown

categoryToText :: ControlCategory -> Text
categoryToText = \case
    SignerControlled -> "signer_controlled"
    ExternalKey -> "external_key"
    Script -> "script"
    Bootstrap -> "bootstrap"
    Unknown -> "unknown"

-- | Accumulator for deterministic output grouping.
data GroupAcc = GroupAcc
    { gaCategory :: ControlCategory
    , gaAddress :: Text
    , gaIndices :: [Int]
    , gaLovelace :: Integer
    , gaAssetKeys :: Set.Set (Text, Text)
    , gaRole :: Text
    , gaProvenance :: EvidenceProvenance
    , gaEvidence :: [EvidenceProvenance]
    }

accToGroup :: GroupAcc -> ControlGroup
accToGroup acc =
    ControlGroup
        { cgCategory = gaCategory acc
        , cgAddresses = [gaAddress acc]
        , cgOutputIndices = sort (gaIndices acc)
        , cgOutputCount = length (gaIndices acc)
        , cgLovelace = T.pack (show (gaLovelace acc))
        , cgAssetClassCount = Set.size (gaAssetKeys acc)
        , cgRole = gaRole acc
        , cgRoleProvenance = gaProvenance acc
        , cgEvidence = gaEvidence acc
        }

{- | Select high-value groups: every group holding at least one percent
of total output lovelace, with the largest non-empty group always
included, ordered by descending lovelace.
-}
selectHighValue :: [ControlGroup] -> Integer -> [ControlGroup]
selectHighValue [] _ = []
selectHighValue _ total | total <= 0 = []
selectHighValue groups total =
    sortBy (comparing (Down . groupLovelace)) selected
  where
    qualifying =
        filter (\g -> groupLovelace g * 100 >= total) groups
    largest = maximumBy (comparing groupLovelace) groups
    selected =
        nub
            ( if largest `elem` qualifying then qualifying else largest : qualifying
            )

groupLovelace :: ControlGroup -> Integer
groupLovelace = fromMaybe 0 . readMaybe . T.unpack . cgLovelace

parseClaim :: Aeson.Value -> Maybe ReviewClaim
parseClaim v = do
    label <- textAt "label" v
    value <- textAt "value" v
    detail <- textAt "detail" v
    pure
        ReviewClaim
            { rclLabel = label
            , rclValue = value
            , rclDetail = detail
            , rclProvenance = MetadataClaim
            , rclSelfDeclared = True
            }

-- JSON navigation helpers (read-only; never interpret prose fields).

lookupKey :: AesonKey.Key -> Aeson.Value -> Maybe Aeson.Value
lookupKey key (Aeson.Object obj) = KeyMap.lookup key obj
lookupKey _ _ = Nothing

textAt :: AesonKey.Key -> Aeson.Value -> Maybe Text
textAt key v =
    case lookupKey key v of
        Just (Aeson.String t) -> Just t
        _ -> Nothing

intAt :: AesonKey.Key -> Aeson.Value -> Maybe Int
intAt key v =
    case lookupKey key v of
        Just (Aeson.Number n) -> Just (floor n)
        _ -> Nothing

boolAt :: AesonKey.Key -> Aeson.Value -> Maybe Bool
boolAt key v =
    case lookupKey key v of
        Just (Aeson.Bool b) -> Just b
        _ -> Nothing

integerTextAt :: AesonKey.Key -> Aeson.Value -> Maybe Integer
integerTextAt key v =
    case lookupKey key v of
        Just (Aeson.String t) -> readMaybe (T.unpack t)
        _ -> Nothing

arrayAt :: AesonKey.Key -> Aeson.Value -> [Aeson.Value]
arrayAt key v =
    case lookupKey key v of
        Just (Aeson.Array a) -> Foldable.toList a
        _ -> []

asText :: Aeson.Value -> Maybe Text
asText (Aeson.String t) = Just t
asText _ = Nothing
