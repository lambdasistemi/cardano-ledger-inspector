{-# LANGUAGE OverloadedStrings #-}

{- | WASI reactor entry: read either raw Conway tx hex or a JSON ledger-operation
  envelope on stdin, write JSON on stdout. Error category on stderr, non-zero
  exit, no partial JSON on stdout.
-}
module Main (main) where

import Cardano.Crypto.Hash (hashFromStringAsHex)
import Cardano.Ledger.Hashes (ScriptHash (..))
import qualified Cardano.Tx.Blueprint as Blueprint
import qualified Cardano.Tx.Decode as TxDecode
import qualified Cardano.Tx.Graph.Emit as TxGraph
import qualified Conway.Inspector as Inspector
import Data.Aeson ((.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Foldable as Foldable
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import qualified Data.Text.Encoding as TextEncoding
import System.Exit (exitFailure, exitSuccess)
import System.IO (hPutStrLn, stderr, stdout)

data RdfRequest
    = RdfRequest T.Text T.Text [(ScriptHash, Blueprint.Blueprint, T.Text)]

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
                            Just (Aeson.String txCbor) -> do
                                blueprints <- parseBlueprints value
                                Right (RdfRequest operation txCbor blueprints)
                            _ ->
                                Left "tx_cbor must be a string"
                _ ->
                    Nothing
        _ ->
            Nothing

parseBlueprints
    :: Aeson.Object
    -> Either String [(ScriptHash, Blueprint.Blueprint, T.Text)]
parseBlueprints value =
    case KeyMap.lookup "args" value of
        Nothing ->
            Right []
        Just Aeson.Null ->
            Right []
        Just (Aeson.Object args) ->
            case KeyMap.lookup "blueprints" args of
                Nothing ->
                    Right []
                Just Aeson.Null ->
                    Right []
                Just (Aeson.Array entries) ->
                    concat
                        <$> traverse
                            (uncurry parseBlueprintEntry)
                            (zip [0 :: Int ..] (Foldable.toList entries))
                _ ->
                    Left "args.blueprints must be an array"
        _ ->
            Left "args must be an object"

parseBlueprintEntry
    :: Int
    -> Aeson.Value
    -> Either String [(ScriptHash, Blueprint.Blueprint, T.Text)]
parseBlueprintEntry ix (Aeson.Object value) = do
    blueprintId <- case KeyMap.lookup "id" value of
        Just (Aeson.String identifier) ->
            Right identifier
        _ ->
            Left ("args.blueprints[" <> show ix <> "].id must be a string")
    plutusJSON <- case KeyMap.lookup "plutus_json" value of
        Just raw ->
            parsePlutusJSONPayload blueprintId raw
        Nothing ->
            Left (blueprintLabel blueprintId <> ": plutus_json is required")
    blueprint <-
        mapLeft
            ( \err ->
                blueprintLabel blueprintId
                    <> ": invalid plutus_json: "
                    <> oneLine err
            )
            (Blueprint.parseBlueprintJSON plutusJSON)
    jsonValue <-
        mapLeft
            ( \err ->
                blueprintLabel blueprintId
                    <> ": invalid plutus_json: "
                    <> oneLine err
            )
            (Aeson.eitherDecode plutusJSON)
    hashes <- validatorHashes blueprintId jsonValue
    let title = Blueprint.preambleTitle (Blueprint.blueprintPreamble blueprint)
    Right [(scriptHash, blueprint, title) | scriptHash <- hashes]
parseBlueprintEntry ix _ =
    Left ("args.blueprints[" <> show ix <> "] must be an object")

parsePlutusJSONPayload
    :: T.Text -> Aeson.Value -> Either String BSL.ByteString
parsePlutusJSONPayload _ (Aeson.String raw) =
    Right (BSL.fromStrict (TextEncoding.encodeUtf8 raw))
parsePlutusJSONPayload _ raw@(Aeson.Object _) =
    Right (Aeson.encode raw)
parsePlutusJSONPayload blueprintId _ =
    Left
        ( blueprintLabel blueprintId
            <> ": plutus_json must be a string or object"
        )

validatorHashes :: T.Text -> Aeson.Value -> Either String [ScriptHash]
validatorHashes blueprintId (Aeson.Object value) =
    case KeyMap.lookup "validators" value of
        Nothing ->
            Right []
        Just (Aeson.Array validators) ->
            concat
                <$> traverse
                    (uncurry (validatorHash blueprintId))
                    (zip [0 :: Int ..] (Foldable.toList validators))
        _ ->
            Left (blueprintLabel blueprintId <> ": validators must be an array")
validatorHashes blueprintId _ =
    Left (blueprintLabel blueprintId <> ": plutus_json must be an object")

validatorHash
    :: T.Text -> Int -> Aeson.Value -> Either String [ScriptHash]
validatorHash blueprintId ix (Aeson.Object value) =
    case KeyMap.lookup "hash" value of
        Nothing ->
            Right []
        Just (Aeson.String hashText) ->
            (: []) <$> parseScriptHash blueprintId ix hashText
        _ ->
            Left
                ( blueprintLabel blueprintId
                    <> ": validators["
                    <> show ix
                    <> "].hash must be a string"
                )
validatorHash blueprintId ix _ =
    Left
        ( blueprintLabel blueprintId
            <> ": validators["
            <> show ix
            <> "] must be an object"
        )

parseScriptHash :: T.Text -> Int -> T.Text -> Either String ScriptHash
parseScriptHash blueprintId ix hashText
    | T.length hashText /= 56 =
        Left (hashDiagnostic "must be 56 hex characters")
    | otherwise =
        case hashFromStringAsHex (T.unpack hashText) of
            Just hashValue ->
                Right (ScriptHash hashValue)
            Nothing ->
                Left (hashDiagnostic "must be valid hex")
  where
    hashDiagnostic detail =
        blueprintLabel blueprintId
            <> ": validators["
            <> show ix
            <> "].hash "
            <> detail

blueprintLabel :: T.Text -> String
blueprintLabel blueprintId =
    "blueprint " <> T.unpack blueprintId

mapLeft :: (a -> b) -> Either a c -> Either b c
mapLeft f = either (Left . f) Right

oneLine :: String -> String
oneLine =
    unwords . words

runRdfOperation :: RdfRequest -> IO ()
runRdfOperation (RdfRequest operation txCbor blueprints) =
    case TxDecode.decodeConwayTxInput (TextEncoding.encodeUtf8 txCbor) of
        Left (TxDecode.TxInputDecodeError err) ->
            die "malformed_cbor" (T.unpack err)
        Right tx ->
            case TxGraph.emit tx Map.empty [] blueprints of
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
