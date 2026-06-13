{-# LANGUAGE OverloadedStrings #-}

{- | WASI reactor entry: read either raw Conway tx hex or a JSON ledger-operation
  envelope on stdin, write JSON on stdout. Error category on stderr, non-zero
  exit, no partial JSON on stdout.
-}
module Main (main) where

import qualified Cardano.Tx.Decode as TxDecode
import qualified Cardano.Tx.Graph.Emit as TxGraph
import qualified Conway.Inspector as Inspector
import Data.Aeson ((.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import qualified Data.Text.Encoding as TextEncoding
import System.Exit (exitFailure, exitSuccess)
import System.IO (hPutStrLn, stderr, stdout)

data RdfRequest = RdfRequest T.Text T.Text

main :: IO ()
main = do
    input <- BS.getContents
    case parseRdfRequest input of
        Just (Left err) ->
            die "malformed_ledger_operation" err
        Just (Right request) ->
            runRdfOperation request
        Nothing ->
            runInspectorOperation input

parseRdfRequest :: BS.ByteString -> Maybe (Either String RdfRequest)
parseRdfRequest input =
    case Aeson.decodeStrict' input of
        Just (Aeson.Object value) ->
            case KeyMap.lookup "op" value of
                Just (Aeson.String operation)
                    | operation == "tx.rdf" || operation == "tx.graph" ->
                        Just $ case KeyMap.lookup "tx_cbor" value of
                            Just (Aeson.String txCbor) ->
                                Right (RdfRequest operation txCbor)
                            _ ->
                                Left "tx_cbor must be a string"
                _ ->
                    Nothing
        _ ->
            Nothing

runRdfOperation :: RdfRequest -> IO ()
runRdfOperation (RdfRequest operation txCbor) =
    case TxDecode.decodeConwayTxInput (TextEncoding.encodeUtf8 txCbor) of
        Left (TxDecode.TxInputDecodeError err) ->
            die "malformed_cbor" (T.unpack err)
        Right tx ->
            case TxGraph.emit tx Map.empty [] [] of
                Left err ->
                    die
                        "malformed_ledger_operation"
                        (TxGraph.renderEmitError err)
                Right graph ->
                    writeJson (rdfResponse operation graph)

rdfResponse :: T.Text -> TxGraph.EmittedGraph -> Aeson.Value
rdfResponse operation graph =
    Aeson.object
        [ "ledger_functional_layer"
            .= ("cardano-ledger-functional/v1" :: T.Text)
        , "op" .= operation
        , "result"
            .= Aeson.object
                [ "rdf"
                    .= Aeson.object
                        [ "format" .= ("text/turtle" :: T.Text)
                        , "turtle" .= turtle
                        ]
                ]
        ]
  where
    turtle =
        TextEncoding.decodeUtf8 $
            TxGraph.serialize TxGraph.Turtle "tx-rdf" graph

runInspectorOperation :: BS.ByteString -> IO ()
runInspectorOperation input =
    case Inspector.runLedgerOperationInput input of
        Left (Inspector.MalformedHex err) -> die "malformed_hex" err
        Left (Inspector.MalformedCbor err) -> die "malformed_cbor" err
        Left (Inspector.MalformedLedgerOperation err) ->
            die "malformed_ledger_operation" err
        Left (Inspector.UnknownLedgerOperation operation) ->
            die "unknown_ledger_operation" (T.unpack operation)
        Right value -> writeJson value

writeJson :: (Aeson.ToJSON a) => a -> IO ()
writeJson value = do
    BSL.hPut stdout (Aeson.encode value)
    BSL.hPut stdout "\n"
    exitSuccess

die :: String -> String -> IO a
die category detail = do
    hPutStrLn stderr (category <> ": " <> detail)
    exitFailure
