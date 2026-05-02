{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosisHost.Diagnosis
    ( runIntent
    , runValidate
    , buildIntentRequest
    , buildValidateRequest
    , buildProducerTxsObject
    , showInspectError
    ) where

import qualified Conway.Inspector as Inspector
import Data.Aeson (Value)
import qualified Data.Aeson as A
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BSL
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text

runIntent :: Text -> Either String Value
runIntent txHex = callInspector (buildIntentRequest txHex)

runValidate :: Text -> Map Text Text -> Either String Value
runValidate txHex producerTxs =
    callInspector (buildValidateRequest txHex producerTxs)

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
buildIntentRequest txHex = A.object
    [ ("ledger_functional_layer", A.String "cardano-ledger-functional/v1")
    , ("tx_cbor", A.String txHex)
    , ("op", A.String "tx.intent")
    , ("args", A.object [])
    ]

buildValidateRequest :: Text -> Map Text Text -> Value
buildValidateRequest txHex producerTxs = A.object
    [ ("ledger_functional_layer", A.String "cardano-ledger-functional/v1")
    , ("tx_cbor", A.String txHex)
    , ("op", A.String "tx.validate")
    , ("args", A.object
        [ ("context", A.object
            [ ("producer_txs", buildProducerTxsObject producerTxs) ]) ])
    ]

buildProducerTxsObject :: Map Text Text -> Value
buildProducerTxsObject m = A.object
    [ ( Key.fromText txHash
      , A.object
          [ ("tx_cbor", A.String cborHex)
          , ("source", A.String "blockfrost.txs.cbor")
          ]
      )
    | (txHash, cborHex) <- Map.toList m
    ]
