{-# LANGUAGE LambdaCase #-}

-- | Private native conformance runner for the canonical operation wrapper.
module Main (main) where

import qualified Conway.Inspector as Inspector
import qualified Data.Aeson as Aeson
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Text as T
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr, stdout)

main :: IO ()
main = do
    input <- BS.getContents
    case Inspector.runLedgerOperationInput input of
        Right value -> do
            BSL.hPut stdout (Aeson.encode value)
            BSL.hPut stdout (BSL.singleton 10)
        Left err -> do
            hPutStrLn stderr (errorMessage err)
            exitFailure

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
