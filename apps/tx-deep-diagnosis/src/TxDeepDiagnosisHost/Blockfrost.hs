{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosisHost.Blockfrost
    ( Network (..)
    , networkBaseUrl
    , networkLedgerName
    , CredentialKind (..)
    , ResolvedOutput (..)
    , ResolvedAsset (..)
    , LatestBlock (..)
    , AccountInfo (..)
    , fetchTxUtxos
    , fetchTxCbor
    , fetchOutputAtIndex
    , fetchLatestBlock
    , fetchProtocolParametersJson
    , fetchAccountInfo
    , remapPParamsToLedger
    , stakeAddressBech32
    ) where

import qualified Codec.Binary.Bech32 as Bech32
import Control.Exception (SomeException, try)
import Data.Aeson
    ( FromJSON (..)
    , eitherDecode
    , withObject
    , (.!=)
    , (.:)
    , (.:?)
    )
import qualified Data.Aeson as A
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Lazy as BSL
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Data.Word (Word8)
import Network.HTTP.Client
import Network.HTTP.Types.Header (hAccept)
import Network.HTTP.Types.Status (statusCode)

data Network = Mainnet | Preprod | Preview
    deriving (Eq, Show)

networkBaseUrl :: Network -> Text
networkBaseUrl Mainnet = "https://cardano-mainnet.blockfrost.io/api/v0"
networkBaseUrl Preprod = "https://cardano-preprod.blockfrost.io/api/v0"
networkBaseUrl Preview = "https://cardano-preview.blockfrost.io/api/v0"

-- The string the ledger expects in the validation context's "network" field.
networkLedgerName :: Network -> Text
networkLedgerName Mainnet = "mainnet"
networkLedgerName _ = "testnet"

data ResolvedAsset = ResolvedAsset
    { rAssetUnit :: !Text
    , rAssetQty :: !Integer
    }
    deriving (Show)

data ResolvedOutput = ResolvedOutput
    { rOutIx :: !Int
    , rOutAddress :: !Text
    , rOutAssets :: ![ResolvedAsset]
    , rOutInlineDatum :: !(Maybe Text)
    , rOutDataHash :: !(Maybe Text)
    , rOutScriptRefHash :: !(Maybe Text)
    }
    deriving (Show)

instance FromJSON ResolvedAsset where
    parseJSON = withObject "ResolvedAsset" $ \o -> do
        unit <- o .: "unit"
        qtyStr <- o .: "quantity"
        qty <- case Text.unpack qtyStr of
            s -> case reads s of
                [(n, "")] -> pure n
                _ -> fail ("bad quantity: " <> s)
        pure ResolvedAsset{rAssetUnit = unit, rAssetQty = qty}

instance FromJSON ResolvedOutput where
    parseJSON = withObject "ResolvedOutput" $ \o ->
        ResolvedOutput
            <$> o .: "output_index"
            <*> o .: "address"
            <*> o .: "amount"
            <*> o .:? "inline_datum"
            <*> o .:? "data_hash"
            <*> o .:? "reference_script_hash"

newtype UtxosResponse = UtxosResponse {urOutputs :: [ResolvedOutput]}

instance FromJSON UtxosResponse where
    parseJSON = withObject "UtxosResponse" $ \o ->
        UtxosResponse <$> o .:? "outputs" .!= []

newtype CborResponse = CborResponse {crCbor :: Text}

instance FromJSON CborResponse where
    parseJSON = withObject "CborResponse" $ \o -> CborResponse <$> o .: "cbor"

fetchTxUtxos
    :: Manager
    -> Network
    -> Text
    -> Text
    -> IO (Either String [ResolvedOutput])
fetchTxUtxos mgr net pid txHash = do
    let url = networkBaseUrl net <> "/txs/" <> txHash <> "/utxos"
    eBody <- callBlockfrost mgr url pid
    pure $ case eBody of
        Left e -> Left e
        Right body -> case eitherDecode body of
            Left e -> Left ("JSON decode error: " <> e)
            Right (UtxosResponse outs) -> Right outs

fetchTxCbor
    :: Manager -> Network -> Text -> Text -> IO (Either String Text)
fetchTxCbor mgr net pid txHash = do
    let url = networkBaseUrl net <> "/txs/" <> txHash <> "/cbor"
    eBody <- callBlockfrost mgr url pid
    pure $ case eBody of
        Left e -> Left e
        Right body -> case eitherDecode body of
            Left e -> Left ("JSON decode error: " <> e)
            Right (CborResponse h) -> Right h

fetchOutputAtIndex
    :: Manager
    -> Network
    -> Text
    -> Text
    -> Int
    -> IO (Either String (Maybe ResolvedOutput))
fetchOutputAtIndex mgr net pid txHash ix = do
    eOuts <- fetchTxUtxos mgr net pid txHash
    pure $
        fmap
            ( \outs -> case [o | o <- outs, rOutIx o == ix] of
                (o : _) -> Just o
                [] -> Nothing
            )
            eOuts

data LatestBlock = LatestBlock
    { lbSlot :: !Integer
    , lbEpoch :: !Integer
    }
    deriving (Show)

instance FromJSON LatestBlock where
    parseJSON = withObject "LatestBlock" $ \o ->
        LatestBlock <$> o .: "slot" <*> o .: "epoch"

fetchLatestBlock
    :: Manager -> Network -> Text -> IO (Either String LatestBlock)
fetchLatestBlock mgr net pid = do
    let url = networkBaseUrl net <> "/blocks/latest"
    eBody <- callBlockfrost mgr url pid
    pure $ case eBody of
        Left e -> Left e
        Right body -> case eitherDecode body of
            Left e -> Left ("JSON decode error: " <> e)
            Right blk -> Right blk

-- Returns the raw Blockfrost protocol-parameters JSON. Use
-- 'remapPParamsToLedger' to convert into the camelCase shape the
-- ledger functional layer expects.
fetchProtocolParametersJson
    :: Manager -> Network -> Text -> IO (Either String A.Value)
fetchProtocolParametersJson mgr net pid = do
    let url = networkBaseUrl net <> "/epochs/latest/parameters"
    eBody <- callBlockfrost mgr url pid
    pure $ case eBody of
        Left e -> Left e
        Right body -> case eitherDecode body of
            Left e -> Left ("JSON decode error: " <> e)
            Right v -> Right v

-- Port of docs/inspector/src/FFI/Blockfrost.js lines 31-98
-- (blockfrostParamsToLedgerPParams). Maps Blockfrost's snake_case
-- protocol-parameter shape to the camelCase shape the ledger
-- functional layer accepts.
remapPParamsToLedger :: A.Value -> A.Value
remapPParamsToLedger raw = case raw of
    A.Object o
        | KeyMap.member (Key.fromString "txFeePerByte") o
            && KeyMap.member (Key.fromString "protocolVersion") o ->
            A.Object o
    A.Object o -> A.object (remapEntries o)
    _ -> raw
  where
    remapEntries o =
        let lookFirst ks = case [v | k <- ks, Just v <- [lookupVal k o]] of
                (v : _) -> Just v
                [] -> Nothing
            num k = numberOrNull (lookupVal k o)
            numFirst ks = numberOrNull (lookFirst ks)
            asProtocolVersion =
                A.object
                    [ ("major", num "protocol_major_ver")
                    , ("minor", num "protocol_minor_ver")
                    ]
            asExUnitPrices =
                A.object
                    [ ("priceMemory", num "price_mem")
                    , ("priceSteps", num "price_step")
                    ]
            asMaxTxEx =
                A.object
                    [ ("memory", num "max_tx_ex_mem")
                    , ("steps", num "max_tx_ex_steps")
                    ]
            asMaxBlockEx =
                A.object
                    [ ("memory", num "max_block_ex_mem")
                    , ("steps", num "max_block_ex_steps")
                    ]
            asPoolVoting =
                A.object
                    [ ("motionNoConfidence", num "pvt_motion_no_confidence")
                    , ("committeeNormal", num "pvt_committee_normal")
                    , ("committeeNoConfidence", num "pvt_committee_no_confidence")
                    , ("hardForkInitiation", num "pvt_hard_fork_initiation")
                    ,
                        ( "ppSecurityGroup"
                        , numFirst ["pvt_p_p_security_group", "pvtpp_security_group"]
                        )
                    ]
            asDRepVoting =
                A.object
                    [ ("motionNoConfidence", num "dvt_motion_no_confidence")
                    , ("committeeNormal", num "dvt_committee_normal")
                    , ("committeeNoConfidence", num "dvt_committee_no_confidence")
                    , ("updateToConstitution", num "dvt_update_to_constitution")
                    , ("hardForkInitiation", num "dvt_hard_fork_initiation")
                    , ("ppNetworkGroup", num "dvt_p_p_network_group")
                    , ("ppEconomicGroup", num "dvt_p_p_economic_group")
                    , ("ppTechnicalGroup", num "dvt_p_p_technical_group")
                    , ("ppGovGroup", num "dvt_p_p_gov_group")
                    , ("treasuryWithdrawal", num "dvt_treasury_withdrawal")
                    ]
            costModels =
                fromMaybe A.Null (lookFirst ["cost_models_raw", "cost_models"])
        in  [ ("txFeePerByte", num "min_fee_a")
            , ("txFeeFixed", num "min_fee_b")
            , ("maxBlockBodySize", num "max_block_size")
            , ("maxTxSize", num "max_tx_size")
            , ("maxBlockHeaderSize", num "max_block_header_size")
            , ("stakeAddressDeposit", num "key_deposit")
            , ("stakePoolDeposit", num "pool_deposit")
            , ("poolRetireMaxEpoch", num "e_max")
            , ("stakePoolTargetNum", num "n_opt")
            , ("poolPledgeInfluence", num "a0")
            , ("monetaryExpansion", num "rho")
            , ("treasuryCut", num "tau")
            , ("protocolVersion", asProtocolVersion)
            , ("minPoolCost", num "min_pool_cost")
            ,
                ( "utxoCostPerByte"
                , numFirst ["coins_per_utxo_size", "coins_per_utxo_word"]
                )
            , ("costModels", costModels)
            , ("executionUnitPrices", asExUnitPrices)
            , ("maxTxExecutionUnits", asMaxTxEx)
            , ("maxBlockExecutionUnits", asMaxBlockEx)
            , ("maxValueSize", num "max_val_size")
            , ("collateralPercentage", num "collateral_percent")
            , ("maxCollateralInputs", num "max_collateral_inputs")
            , ("poolVotingThresholds", asPoolVoting)
            , ("dRepVotingThresholds", asDRepVoting)
            , ("committeeMinSize", num "committee_min_size")
            , ("committeeMaxTermLength", num "committee_max_term_length")
            , ("govActionLifetime", num "gov_action_lifetime")
            , ("govActionDeposit", num "gov_action_deposit")
            , ("dRepDeposit", num "drep_deposit")
            , ("dRepActivity", num "drep_activity")
            , ("minFeeRefScriptCostPerByte", num "min_fee_ref_script_cost_per_byte")
            ]
    lookupVal k = KeyMap.lookup (Key.fromString k)
    numberOrNull Nothing = A.Null
    numberOrNull (Just (A.String t)) = case Text.unpack t of
        s -> case reads s :: [(Double, String)] of
            [(n, "")] -> A.toJSON n
            _ -> A.Null
    numberOrNull (Just v@(A.Number _)) = v
    numberOrNull (Just A.Null) = A.Null
    numberOrNull (Just other) = other

{- | Whether a stake credential is a key hash or a script hash. The
 encoding only differs in one bit of the address header byte.
-}
data CredentialKind = KeyCred | ScriptCred
    deriving (Eq, Show)

{- | The handful of fields the deep-diagnosis tool needs from
 @GET /accounts/{stake_address}@. Other fields (delegation,
 rewards_sum, controlled_amount, …) are intentionally ignored.
-}
data AccountInfo = AccountInfo
    { aiActive :: !Bool
    -- ^ Whether the credential is currently delegated to a stake pool.
    -- For trigger-only stake scripts (SundaeSwap, Indigo, …) this is
    -- usually @false@ even when the account is fully registered and
    -- usable as a withdraw-zero target — they never delegate ADA.
    , aiRegistered :: !Bool
    -- ^ Whether the credential has *ever* been registered. This is the
    -- field that matters for the CERTS withdrawal rule: a registered
    -- account exists in the rewards map (with whatever balance) and
    -- can be the target of a withdrawal; an unregistered credential
    -- cannot.
    , aiWithdrawableLovelace :: !Integer
    -- ^ Current rewards balance in lovelace. The withdrawal in the tx
    -- body must equal this exactly (typically 0 for withdraw-zero
    -- triggers).
    }
    deriving (Show)

instance FromJSON AccountInfo where
    parseJSON = withObject "AccountInfo" $ \o -> do
        active <- o .: "active"
        registered <- o .:? "registered" .!= active
        wd <- o .: "withdrawable_amount"
        n <- case Text.unpack wd of
            s -> case reads s of
                [(n, "")] -> pure n
                _ -> fail ("bad withdrawable_amount: " <> s)
        pure
            AccountInfo
                { aiActive = active
                , aiRegistered = registered
                , aiWithdrawableLovelace = n
                }

{- | Fetch the account state for the given bech32 stake address. Use
 'stakeAddressBech32' to derive the address from a credential.
-}
fetchAccountInfo
    :: Manager -> Network -> Text -> Text -> IO (Either String AccountInfo)
fetchAccountInfo mgr net pid stake = do
    let url = networkBaseUrl net <> "/accounts/" <> stake
    eBody <- callBlockfrost mgr url pid
    pure $ case eBody of
        Left e -> Left e
        Right body -> case eitherDecode body of
            Left e -> Left ("JSON decode error: " <> e)
            Right info -> Right info

{- | Encode a stake credential as a bech32 stake address suitable for the
  @GET /accounts/{stake_address}@ endpoint.

  > header_byte = 0xe1 (mainnet, key)   | 0xf1 (mainnet, script)
  >             | 0xe0 (testnet, key)   | 0xf0 (testnet, script)
  > address     = header_byte || 28-byte credential hash
  > hrp         = "stake" (mainnet)     | "stake_test" (testnet)
-}
stakeAddressBech32
    :: Network -> CredentialKind -> Text -> Either String Text
stakeAddressBech32 net kind hashHex = do
    bytes <- case B16.decode (TE.encodeUtf8 hashHex) of
        Right bs -> Right bs
        Left err -> Left ("hash hex decode failed: " <> err)
    if BS.length bytes /= 28
        then
            Left
                ( "expected 28 bytes for credential hash, got "
                    <> show (BS.length bytes)
                )
        else
            let header :: Word8
                header = case (net, kind) of
                    (Mainnet, KeyCred) -> 0xe1
                    (Mainnet, ScriptCred) -> 0xf1
                    (_, KeyCred) -> 0xe0
                    (_, ScriptCred) -> 0xf0
                payload = BS.cons header bytes
                hrpText = case net of
                    Mainnet -> "stake"
                    _ -> "stake_test"
            in  case Bech32.humanReadablePartFromText hrpText of
                    Left err -> Left ("bad hrp: " <> show err)
                    Right hrp ->
                        Right (Bech32.encodeLenient hrp (Bech32.dataPartFromBytes payload))

callBlockfrost
    :: Manager -> Text -> Text -> IO (Either String BSL.ByteString)
callBlockfrost mgr url pid = do
    eResult <-
        try
            ( do
                initReq <- parseUrlThrow (Text.unpack url)
                let req =
                        initReq
                            { requestHeaders =
                                [(hAccept, "application/json"), ("project_id", TE.encodeUtf8 pid)]
                            , method = "GET"
                            }
                resp <- httpLbs req mgr
                let code = statusCode (responseStatus resp)
                if code == 200
                    then pure $ Right (responseBody resp)
                    else
                        pure $ Left ("Blockfrost " <> show code <> ": " <> Text.unpack url)
            )
            :: IO (Either SomeException (Either String BSL.ByteString))
    case eResult of
        Left e -> pure $ Left ("HTTP error: " <> show e)
        Right r -> pure r
