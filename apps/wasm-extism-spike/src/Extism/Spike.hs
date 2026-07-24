{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Extism.Spike
Description : Extism PDK plugin exposing ledger operations.

Foreign exports delegate to 'Conway.Inspector.runLedgerOperationInput',
which is the same code path the WASI reactor (@wasm-tx-inspector@)
runs on stdin. The plugin's response is therefore byte-identical to the
WASI reactor's response for the same input; that property is what
makes the spike useful for differential conformance testing.

Input is the canonical JSON envelope:

> { "ledger_functional_layer": "...",
>   "tx_cbor": "...",
>   "op": "tx.identify" | "tx.validate" | ...,
>   "args": { ... } }

Output is the matching response envelope. Errors go through
'Extism.PDK.setError'.
-}
module Extism.Spike
    ( txEvaluateScripts
    , txIdentify
    , txIntent
    , txReview
    , txValidate
    )
where

import qualified Conway.Inspector as Inspector
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Text as T
import Extism.PDK (inputByteString, output, setError)

txIdentify :: IO ()
txIdentify = runOp

txIntent :: IO ()
txIntent = runOp

txReview :: IO ()
txReview = runOp

txValidate :: IO ()
txValidate = runOp

txEvaluateScripts :: IO ()
txEvaluateScripts = runOp

runOp :: IO ()
runOp = do
    payload <- inputByteString
    case Inspector.runLedgerOperationInput payload of
        Right value -> output (BSL.toStrict (Aeson.encode value))
        Left err -> setError (errorMessage err)

errorMessage :: Inspector.InspectError -> String
errorMessage = \case
    Inspector.MalformedHex detail ->
        "malformed_hex: " <> detail
    Inspector.MalformedCbor detail ->
        "malformed_cbor: " <> detail
    Inspector.MalformedLedgerOperation detail ->
        "malformed_ledger_operation: " <> detail
    Inspector.UnknownLedgerOperation operation ->
        "unknown_ledger_operation: " <> T.unpack operation

foreign export ccall "tx_identify" txIdentify :: IO ()
foreign export ccall "tx_intent" txIntent :: IO ()
foreign export ccall "tx_review" txReview :: IO ()
foreign export ccall "tx_validate" txValidate :: IO ()
foreign export ccall "tx_evaluate_scripts" txEvaluateScripts :: IO ()
