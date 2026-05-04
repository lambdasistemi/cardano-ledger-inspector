{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosisHost.Diagnosis
    ( ValidationContext (..)
    , WithdrawalCredential (..)
    , emptyContext
    , runIntent
    , runValidate
    , buildIntentRequest
    , buildValidateRequest
    , buildProducerTxsObject
    , extractProducerTxIds
    , extractMissingWithdrawalCredentials
    , showInspectError
    ) where

import qualified Conway.Inspector as Inspector
import Data.Aeson (Value)
import qualified Data.Aeson as A
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BSL
import Data.List (nub)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text

data ValidationContext = ValidationContext
    { vcProducerTxs :: !(Map Text Text)
    , vcNetwork :: !(Maybe Text)
    , vcSlot :: !(Maybe Integer)
    , vcEpoch :: !(Maybe Integer)
    , vcProtocolParameters :: !(Maybe Value)
    , vcCertState :: !(Maybe Value)
    -- ^ Optional cert_state JSON, schema:
    --   @{ "rewards": [{"credential": {"kind","hash"}, "balance_lovelace": "<int>"}] }@
    -- The inspector library reads this to seed the @Accounts@ map
    -- before running Conway @applyTx@ (rewards-only is enough for
    -- withdraw-zero patterns).
    }

{- | A withdrawal credential the validator wants the host to look up
  off-chain. Pulled out of the cert_state @missing_context@ entry's
  @details.withdrawal_credentials@ array.
-}
data WithdrawalCredential = WithdrawalCredential
    { wcKind :: !Text
    , wcHash :: !Text
    }
    deriving (Eq, Ord, Show)

emptyContext :: ValidationContext
emptyContext =
    ValidationContext
        { vcProducerTxs = Map.empty
        , vcNetwork = Nothing
        , vcSlot = Nothing
        , vcEpoch = Nothing
        , vcProtocolParameters = Nothing
        , vcCertState = Nothing
        }

runIntent :: Text -> Either String Value
runIntent txHex = callInspector (buildIntentRequest txHex)

runValidate :: Text -> ValidationContext -> Either String Value
runValidate txHex ctx = callInspector (buildValidateRequest txHex ctx)

callInspector :: Value -> Either String Value
callInspector req =
    case Inspector.runLedgerOperationInput (BSL.toStrict (A.encode req)) of
        Left e -> Left (showInspectError e)
        Right v -> Right v

showInspectError :: Inspector.InspectError -> String
showInspectError (Inspector.MalformedHex s) = "malformed_hex: " <> s
showInspectError (Inspector.MalformedCbor s) = "malformed_cbor: " <> s
showInspectError (Inspector.MalformedLedgerOperation s) = "malformed_op: " <> s
showInspectError (Inspector.UnknownLedgerOperation s) =
    "unknown_op: " <> Text.unpack s

buildIntentRequest :: Text -> Value
buildIntentRequest txHex =
    A.object
        [ ("ledger_functional_layer", A.String "cardano-ledger-functional/v1")
        , ("tx_cbor", A.String txHex)
        , ("op", A.String "tx.intent")
        , ("args", A.object [])
        ]

buildValidateRequest :: Text -> ValidationContext -> Value
buildValidateRequest txHex ctx =
    A.object
        [ ("ledger_functional_layer", A.String "cardano-ledger-functional/v1")
        , ("tx_cbor", A.String txHex)
        , ("op", A.String "tx.validate")
        , ("args", A.object [("context", A.object contextEntries)])
        ]
  where
    contextEntries =
        [("producer_txs", buildProducerTxsObject (vcProducerTxs ctx))]
            <> maybe [] (\n -> [("network", A.String n)]) (vcNetwork ctx)
            <> maybe
                []
                (\s -> [("slot", A.String (Text.pack (show s)))])
                (vcSlot ctx)
            <> maybe
                []
                (\e -> [("epoch", A.String (Text.pack (show e)))])
                (vcEpoch ctx)
            <> maybe
                []
                (\p -> [("protocol_parameters", p)])
                (vcProtocolParameters ctx)
            -- cert_state is required by the validator when the tx has
            -- withdrawals or certificates. The inspector library reads
            -- the @rewards@ entries to seed the Accounts map before
            -- Conway applyTx runs; an empty object still satisfies the
            -- gate but yields no seeded entries (CERTS will then reject
            -- the withdrawal).
            <> maybe [] (\c -> [("cert_state", c)]) (vcCertState ctx)
            <> [
                   ( "source"
                   , A.String "tx-deep-diagnosis.blockfrost+latest+pparams+cert_state"
                   )
               ]

buildProducerTxsObject :: Map Text Text -> Value
buildProducerTxsObject m =
    A.object
        [ ( Key.fromText txHash
          , A.object
                [ ("tx_cbor", A.String cborHex)
                , ("source", A.String "blockfrost.txs.cbor")
                ]
          )
        | (txHash, cborHex) <- Map.toList m
        ]

-- Walk a tx.validate response (the full envelope) and extract the
-- de-duplicated tx hashes whose producer-tx CBOR the validator still
-- needs (i.e. missing_context entries with kind == "source_output").
extractProducerTxIds :: Value -> [Text]
extractProducerTxIds resp =
    nub
        [ txid
        | A.Object root <- [resp]
        , Just (A.Object result) <- [KeyMap.lookup "result" root]
        , Just (A.Object validation) <- [KeyMap.lookup "validation" result]
        , Just (A.Array missing) <- [KeyMap.lookup "missing_context" validation]
        , A.Object entry <- foldr (:) [] missing
        , Just (A.String "source_output") <- [KeyMap.lookup "kind" entry]
        , Just (A.String txid) <- [KeyMap.lookup "tx_id" entry]
        ]

{- | Walk a tx.validate response and extract the de-duplicated stake
  credentials the validator wants the host to look up off-chain. Each
  entry comes from a missing_context @kind == "cert_state"@ row whose
  @details.withdrawal_credentials@ array names the credentials.
-}
extractMissingWithdrawalCredentials :: Value -> [WithdrawalCredential]
extractMissingWithdrawalCredentials resp =
    nub
        [ WithdrawalCredential{wcKind = kind, wcHash = hash}
        | A.Object root <- [resp]
        , Just (A.Object result) <- [KeyMap.lookup "result" root]
        , Just (A.Object validation) <- [KeyMap.lookup "validation" result]
        , Just (A.Array missing) <- [KeyMap.lookup "missing_context" validation]
        , A.Object entry <- foldr (:) [] missing
        , Just (A.String "cert_state") <- [KeyMap.lookup "kind" entry]
        , Just (A.Object details) <- [KeyMap.lookup "details" entry]
        , Just (A.Array creds) <-
            [KeyMap.lookup "withdrawal_credentials" details]
        , A.Object cred <- foldr (:) [] creds
        , Just (A.String kind) <- [KeyMap.lookup "kind" cred]
        , Just (A.String hash) <- [KeyMap.lookup "hash" cred]
        ]
