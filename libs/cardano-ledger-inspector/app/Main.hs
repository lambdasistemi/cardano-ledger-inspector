{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeApplications #-}

{- | WASI reactor entry: read either raw Conway tx hex or a JSON ledger-operation
  envelope on stdin, write JSON on stdout. Error category on stderr, non-zero
  exit, no partial JSON on stdout.
-}
module Main (main) where

import Cardano.Crypto.Hash (hashFromStringAsHex, hashToBytes)
import qualified Cardano.Crypto.Hash as Crypto
import Cardano.Ledger.Address (Addr (..))
import qualified Cardano.Ledger.Api as L
import Cardano.Ledger.Api.Scripts.Data (Data)
import Cardano.Ledger.Api.Tx.Out (TxOut, addrTxOutL)
import Cardano.Ledger.BaseTypes (TxIx (..))
import qualified Cardano.Ledger.BaseTypes as BaseTypes
import Cardano.Ledger.Binary (decodeFullFromHexText, natVersion)
import Cardano.Ledger.Conway (ConwayEra)
import qualified Cardano.Ledger.Core as Core
import Cardano.Ledger.Credential (Credential (ScriptHashObj))
import Cardano.Ledger.Hashes (ScriptHash (..), extractHash)
import qualified Cardano.Ledger.TxIn as TxIn
import qualified Cardano.Tx.Blueprint as Blueprint
import qualified Cardano.Tx.Decode as TxDecode
import qualified Cardano.Tx.Graph.Emit as TxGraph
import qualified Conway.Inspector as Inspector
import qualified Conway.Inspector.ProtocolRegistry as ProtocolRegistry
import Data.Aeson ((.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Lazy as BSL
import Data.Either (fromRight)
import qualified Data.Foldable as Foldable
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, fromMaybe, mapMaybe)
import qualified Data.Set as Set
import qualified Data.Text as T
import qualified Data.Text.Encoding as TextEncoding
import Data.Word (Word64)
import Lens.Micro ((^.))
import System.Exit (exitFailure, exitSuccess)
import System.IO (hPutStrLn, stderr, stdout)

data RdfRequest
    = RdfRequest
        T.Text
        T.Text
        Aeson.Value
        [(ScriptHash, Blueprint.Blueprint, T.Text)]

newtype ProducerContext = ProducerContext
    { pcProducerTxs :: Map.Map T.Text ProducerTx
    }

data ProducerTx = ProducerTx
    { ptSource :: !T.Text
    , ptDecoded :: !(Either T.Text TxDecode.ConwayTx)
    }

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
                                let args =
                                        case KeyMap.lookup "args" value of
                                            Just raw -> raw
                                            Nothing -> Aeson.object []
                                Right
                                    ( RdfRequest
                                        operation
                                        txCbor
                                        args
                                        blueprints
                                    )
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
runRdfOperation (RdfRequest operation txCbor args blueprints) =
    case TxDecode.decodeConwayTxInput (TextEncoding.encodeUtf8 txCbor) of
        Left (TxDecode.TxInputDecodeError err) ->
            die "malformed_cbor" (T.unpack err)
        Right tx -> case producerContextFromArgs args of
            Left err ->
                die "malformed_ledger_operation" err
            Right producerContext -> case resolveRdfUtxo tx producerContext of
                Left err ->
                    die "malformed_ledger_operation" err
                Right resolvedUtxo -> emitRdfGraph operation tx resolvedUtxo blueprints

emitRdfGraph
    :: T.Text
    -> TxDecode.ConwayTx
    -> TxGraph.ResolvedUTxO
    -> [(ScriptHash, Blueprint.Blueprint, T.Text)]
    -> IO ()
emitRdfGraph operation tx resolvedUtxo blueprints =
    case TxGraph.emit tx resolvedUtxo [] blueprints of
        Left err ->
            die
                "malformed_ledger_operation"
                (TxGraph.renderEmitError err)
        Right graph ->
            writeJson (rdfResponse operation graph)

producerContextFromArgs
    :: Aeson.Value -> Either String ProducerContext
producerContextFromArgs Aeson.Null =
    Right (ProducerContext Map.empty)
producerContextFromArgs (Aeson.Object args) =
    case KeyMap.lookup "context" args of
        Nothing ->
            Right (ProducerContext Map.empty)
        Just Aeson.Null ->
            Right (ProducerContext Map.empty)
        Just (Aeson.Object context) ->
            case KeyMap.lookup "producer_txs" context of
                Nothing ->
                    Right (ProducerContext Map.empty)
                Just Aeson.Null ->
                    Right (ProducerContext Map.empty)
                Just (Aeson.Object producerTxs) ->
                    Right $
                        ProducerContext $
                            Map.fromList
                                [ ( keyText
                                  , producerTxFromValue value
                                  )
                                | (key, value) <- KeyMap.toList producerTxs
                                , let keyText = AesonKey.toText key
                                ]
                _ ->
                    Left "args.context.producer_txs must be an object"
        _ ->
            Left "args.context must be an object"
producerContextFromArgs _ =
    Left "args must be an object"

producerTxFromValue :: Aeson.Value -> ProducerTx
producerTxFromValue value =
    let source =
            case lookupValue "source" value of
                Just (Aeson.String s) -> s
                _ -> "context.producer_txs"
    in  ProducerTx
            { ptSource = source
            , ptDecoded =
                case producerTxCbor value of
                    Nothing ->
                        Left "producer transaction is missing tx_cbor"
                    Just txCbor ->
                        case TxDecode.decodeConwayTxInput
                            (TextEncoding.encodeUtf8 txCbor) of
                            Left (TxDecode.TxInputDecodeError err) ->
                                Left err
                            Right tx ->
                                Right tx
            }

producerTxCbor :: Aeson.Value -> Maybe T.Text
producerTxCbor (Aeson.String txCbor) =
    Just txCbor
producerTxCbor (Aeson.Object obj) =
    case KeyMap.lookup "tx_cbor" obj of
        Just (Aeson.String txCbor) -> Just txCbor
        _ -> Nothing
producerTxCbor _ =
    Nothing

lookupValue :: AesonKey.Key -> Aeson.Value -> Maybe Aeson.Value
lookupValue key (Aeson.Object obj) =
    KeyMap.lookup key obj
lookupValue _ _ =
    Nothing

resolveRdfUtxo
    :: TxDecode.ConwayTx
    -> ProducerContext
    -> Either String TxGraph.ResolvedUTxO
resolveRdfUtxo tx context
    | Map.null (pcProducerTxs context) =
        Right Map.empty
    | otherwise = do
        Foldable.traverse_ checkProducer (Map.toList (pcProducerTxs context))
        pairs <- traverse (resolveTxIn context) (currentTxIns tx)
        Right (Map.fromList (catMaybes pairs))

checkProducer :: (T.Text, ProducerTx) -> Either String ()
checkProducer (declaredTxId, ProducerTx{ptDecoded = Left err}) =
    Left $
        "producer_tx_decode_failed: Producer transaction "
            <> T.unpack declaredTxId
            <> " could not be decoded: "
            <> T.unpack err
checkProducer (declaredTxId, ProducerTx{ptDecoded = Right producer}) =
    let actualTxId = txIdHex (Core.txIdTx producer)
    in  if declaredTxId == actualTxId
            then Right ()
            else
                Left $
                    "producer_tx_id_mismatch: declared "
                        <> T.unpack declaredTxId
                        <> " actual "
                        <> T.unpack actualTxId

resolveTxIn
    :: ProducerContext
    -> TxIn.TxIn
    -> Either String (Maybe (TxIn.TxIn, L.TxOut ConwayEra))
resolveTxIn context txIn =
    case Map.lookup (txInTxIdHex txIn) (pcProducerTxs context) of
        Nothing ->
            Right Nothing
        Just ProducerTx{ptDecoded = Left err} ->
            Left $
                "producer_tx_decode_failed: Producer transaction "
                    <> T.unpack (txInTxIdHex txIn)
                    <> " could not be decoded: "
                    <> T.unpack err
        Just ProducerTx{ptSource = source, ptDecoded = Right producer} ->
            case producerOutputAt txIn producer of
                Nothing ->
                    Left $
                        "producer_output_index_missing: "
                            <> T.unpack (txInKey txIn)
                            <> " not found in "
                            <> T.unpack source
                Just txOut ->
                    Right (Just (txIn, txOut))

currentTxIns :: TxDecode.ConwayTx -> [TxIn.TxIn]
currentTxIns tx =
    Foldable.toList (body ^. L.inputsTxBodyL)
        <> Foldable.toList (body ^. L.collateralInputsTxBodyL)
  where
    body = tx ^. L.bodyTxL

producerOutputAt
    :: TxIn.TxIn
    -> TxDecode.ConwayTx
    -> Maybe (L.TxOut ConwayEra)
producerOutputAt txIn producer =
    listAt (txInIndex txIn) $
        Foldable.toList (producer ^. (L.bodyTxL . L.outputsTxBodyL))

listAt :: Int -> [a] -> Maybe a
listAt index xs
    | index < 0 = Nothing
    | otherwise = case drop index xs of
        value : _ -> Just value
        [] -> Nothing

txInKey :: TxIn.TxIn -> T.Text
txInKey txIn =
    txInTxIdHex txIn <> "#" <> T.pack (show (txInIndex txIn))

txInTxIdHex :: TxIn.TxIn -> T.Text
txInTxIdHex (TxIn.TxIn txId _) =
    txIdHex txId

txInIndex :: TxIn.TxIn -> Int
txInIndex (TxIn.TxIn _ (TxIx ix)) =
    fromEnum ix

txIdHex :: TxIn.TxId -> T.Text
txIdHex (TxIn.TxId safeHash) =
    hashHex (extractHash safeHash)

hashHex :: Crypto.Hash h a -> T.Text
hashHex =
    TextEncoding.decodeUtf8 . B16.encode . hashToBytes

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
        Right value -> writeJson (enrichIntentResponse input value)

enrichIntentResponse :: BS.ByteString -> Aeson.Value -> Aeson.Value
enrichIntentResponse input response =
    case (intentTxCbor input, intentResponse response) of
        (Just txCbor, True) ->
            case TxDecode.decodeConwayTxInput (TextEncoding.encodeUtf8 txCbor) of
                Left _ -> response
                Right tx ->
                    insertIntentMetadata tx $
                        ProtocolRegistry.enrichIntent
                            (referenceInputOutrefs tx)
                            (producerInputScriptHashes (intentProducerContext input))
                            (intentRedeemers response)
                            response
        _ -> response

intentTxCbor :: BS.ByteString -> Maybe T.Text
intentTxCbor input = do
    Aeson.Object request <- Aeson.decodeStrict' input
    Aeson.String operation <- KeyMap.lookup "op" request
    Aeson.String txCbor <- KeyMap.lookup "tx_cbor" request
    if operation == "tx.intent" || operation == "intent"
        then Just txCbor
        else Nothing

intentProducerContext :: BS.ByteString -> ProducerContext
intentProducerContext input =
    case Aeson.decodeStrict' input of
        Just (Aeson.Object request) ->
            fromRight (ProducerContext Map.empty) $
                producerContextFromArgs $
                    fromMaybe Aeson.Null (KeyMap.lookup "args" request)
        _ -> ProducerContext Map.empty

{- | Decode redeemers through the pinned Conway ledger decoder.  The
protocol registry only receives already-decoded ledger data; it never
interprets CBOR itself.
-}
intentRedeemers :: Aeson.Value -> Map.Map T.Text (Data ConwayEra)
intentRedeemers response =
    Map.fromList (mapMaybe decodeScript scripts)
  where
    scripts =
        case response of
            Aeson.Object root ->
                maybe [] Foldable.toList $
                    KeyMap.lookup "result" root
                        >>= asObject
                        >>= KeyMap.lookup "intent"
                        >>= asObject
                        >>= KeyMap.lookup "scripts"
                        >>= asArray
            _ -> []
    decodeScript (Aeson.Object script) = do
        Aeson.Object input <- KeyMap.lookup "input" script
        Aeson.String txId <- KeyMap.lookup "tx_id" input
        index <- KeyMap.lookup "index" input >>= asInteger
        Aeson.String cbor <- KeyMap.lookup "redeemer_cbor_hex" script
        datum <- decodePlutusData cbor
        pure (txId <> "#" <> T.pack (show index), datum)
    decodeScript _ = Nothing
    asObject (Aeson.Object value) = Just value
    asObject _ = Nothing
    asArray (Aeson.Array value) = Just value
    asArray _ = Nothing
    asInteger (Aeson.Number value) = Just (floor value :: Integer)
    asInteger _ = Nothing

decodePlutusData :: T.Text -> Maybe (Data ConwayEra)
decodePlutusData hex =
    either (const Nothing) Just $
        decodeFullFromHexText (natVersion @11) (T.strip hex)

referenceInputOutrefs :: TxDecode.ConwayTx -> [T.Text]
referenceInputOutrefs tx =
    map txInOutref $
        Set.toAscList $
            tx ^. (Core.bodyTxL . L.referenceInputsTxBodyL)

producerInputScriptHashes :: ProducerContext -> Map.Map T.Text T.Text
producerInputScriptHashes (ProducerContext producers) =
    Map.fromList $
        concatMap producerOutputs (Map.toList producers)
  where
    producerOutputs (txId, ProducerTx _ (Right tx)) =
        mapMaybe
            ( \(ix, output) ->
                fmap
                    (txId <> "#" <> T.pack (show ix),)
                    (outputScriptHash output)
            )
            ( zip
                [0 :: Int ..]
                (Foldable.toList (tx ^. (Core.bodyTxL . L.outputsTxBodyL)))
            )
    producerOutputs _ = []

outputScriptHash :: TxOut ConwayEra -> Maybe T.Text
outputScriptHash output =
    case output ^. addrTxOutL of
        Addr _ (ScriptHashObj (ScriptHash hash)) _ ->
            Just (TextEncoding.decodeUtf8 (B16.encode (hashToBytes hash)))
        _ -> Nothing

txInOutref :: TxIn.TxIn -> T.Text
txInOutref (TxIn.TxIn (TxIn.TxId hash) (TxIx index)) =
    TextEncoding.decodeUtf8 (B16.encode (hashToBytes (extractHash hash)))
        <> "#"
        <> T.pack (show index)

intentResponse :: Aeson.Value -> Bool
intentResponse (Aeson.Object response) =
    KeyMap.lookup "op" response == Just (Aeson.String "tx.intent")
intentResponse _ = False

insertIntentMetadata
    :: TxDecode.ConwayTx -> Aeson.Value -> Aeson.Value
insertIntentMetadata tx (Aeson.Object response) =
    Aeson.Object $ case KeyMap.lookup "result" response of
        Nothing -> response
        Just result -> KeyMap.insert "result" (insertIntoResult result) response
  where
    insertIntoResult (Aeson.Object result) =
        Aeson.Object $ case KeyMap.lookup "intent" result of
            Nothing -> result
            Just intent -> KeyMap.insert "intent" (insertIntoIntent intent) result
    insertIntoResult result = result

    insertIntoIntent (Aeson.Object intent) =
        Aeson.Object $
            KeyMap.insert
                "auxiliary_data"
                (Aeson.object ["metadata" .= typedMetadataEntries tx])
                intent
    insertIntoIntent intent = intent
insertIntentMetadata _ response = response

typedMetadataEntries :: TxDecode.ConwayTx -> [Aeson.Value]
typedMetadataEntries tx =
    case tx ^. Core.auxDataTxL of
        BaseTypes.SNothing -> []
        BaseTypes.SJust auxData ->
            map
                typedMetadataEntry
                (Map.toList (auxData ^. Core.metadataTxAuxDataL))

typedMetadataEntry :: (Word64, L.Metadatum) -> Aeson.Value
typedMetadataEntry (label, value) =
    Aeson.object
        [ "label" .= T.pack (show label)
        , "value" .= typedMetadataValue value
        ]

typedMetadataValue :: L.Metadatum -> Aeson.Value
typedMetadataValue datum =
    case datum of
        L.I number ->
            Aeson.object
                [ "type" .= ("int" :: T.Text)
                , "value" .= T.pack (show number)
                ]
        L.B bytes ->
            Aeson.object
                [ "type" .= ("bytes" :: T.Text)
                , "hex" .= TextEncoding.decodeUtf8 (B16.encode bytes)
                ]
        L.S text ->
            Aeson.object
                [ "type" .= ("text" :: T.Text)
                , "value" .= text
                ]
        L.List items ->
            Aeson.object
                [ "type" .= ("list" :: T.Text)
                , "items" .= map typedMetadataValue items
                ]
        L.Map entries ->
            Aeson.object
                [ "type" .= ("map" :: T.Text)
                , "entries"
                    .= [ Aeson.object
                        [ "key" .= typedMetadataValue key
                        , "value" .= typedMetadataValue value
                        ]
                       | (key, value) <- entries
                       ]
                ]

writeJson :: (Aeson.ToJSON a) => a -> IO ()
writeJson value = do
    BSL.hPut stdout (Aeson.encode value)
    BSL.hPut stdout "\n"
    exitSuccess

die :: String -> String -> IO a
die category detail = do
    hPutStrLn stderr (category <> ": " <> detail)
    exitFailure
