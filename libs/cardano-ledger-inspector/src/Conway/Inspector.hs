{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeApplications #-}

{- |
Module      : Conway.Inspector
Description : Target-independent Conway ledger-operation wrapper.

The external @cardano-ledger-wasm@ package remains the ledger kernel. This
module preserves its public operation entry point and error type, then applies
the local typed-metadata and protocol-registry enrichments to successful
@tx.intent@ responses.
-}
module Conway.Inspector
    ( InspectError (..)
    , runLedgerOperationInput
    )
where

import Cardano.Crypto.Hash (hashToBytes)
import Cardano.Ledger.Address (Addr (..))
import Cardano.Ledger.Alonzo.Core (TopTx, Tx)
import qualified Cardano.Ledger.Api as L
import Cardano.Ledger.Api.Scripts.Data (Data)
import Cardano.Ledger.Api.Tx.Out (TxOut, addrTxOutL)
import Cardano.Ledger.BaseTypes (TxIx (..))
import qualified Cardano.Ledger.BaseTypes as BaseTypes
import Cardano.Ledger.Binary
    ( Annotator
    , Decoder
    , decCBOR
    , decodeFullAnnotatorFromHexText
    , decodeFullFromHexText
    , natVersion
    )
import Cardano.Ledger.Conway (ConwayEra)
import qualified Cardano.Ledger.Core as Core
import Cardano.Ledger.Credential (Credential (ScriptHashObj))
import Cardano.Ledger.Hashes (ScriptHash (..), extractHash)
import qualified Cardano.Ledger.TxIn as TxIn
import qualified Conway.Inspector.ProtocolRegistry as ProtocolRegistry
import Data.Aeson ((.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import Data.Either (fromRight)
import qualified Data.Foldable as Foldable
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, mapMaybe)
import qualified Data.Set as Set
import qualified Data.Text as T
import qualified Data.Text.Encoding as TextEncoding
import Data.Word (Word64)
import Lens.Micro ((^.))
import "cardano-ledger-wasm" Conway.Inspector (InspectError (..))
import qualified "cardano-ledger-wasm" Conway.Inspector as Kernel

newtype ProducerContext = ProducerContext
    { pcProducerTxs :: Map.Map T.Text ProducerTx
    }

type ConwayTx = Tx TopTx ConwayEra

newtype ProducerTx = ProducerTx
    { ptDecoded :: Either T.Text ConwayTx
    }

-- | Run the pinned ledger kernel and enrich successful intent responses.
runLedgerOperationInput
    :: BS.ByteString -> Either InspectError Aeson.Value
runLedgerOperationInput input =
    enrichIntentResponse input <$> Kernel.runLedgerOperationInput input

enrichIntentResponse :: BS.ByteString -> Aeson.Value -> Aeson.Value
enrichIntentResponse input response =
    case (intentTxCbor input, intentResponse response) of
        (Just txCbor, True) ->
            case decodeConwayTxInput txCbor of
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
                                [ ( AesonKey.toText key
                                  , producerTxFromValue value
                                  )
                                | (key, value) <- KeyMap.toList producerTxs
                                ]
                _ ->
                    Left "args.context.producer_txs must be an object"
        _ ->
            Left "args.context must be an object"
producerContextFromArgs _ =
    Left "args must be an object"

producerTxFromValue :: Aeson.Value -> ProducerTx
producerTxFromValue value =
    ProducerTx
        { ptDecoded =
            case producerTxCbor value of
                Nothing ->
                    Left "producer transaction is missing tx_cbor"
                Just txCbor ->
                    decodeConwayTxInput txCbor
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

{- | Decode redeemers through the pinned Conway ledger decoder. The protocol
registry receives already-decoded ledger data and never interprets CBOR.
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

decodeConwayTxInput :: T.Text -> Either T.Text ConwayTx
decodeConwayTxInput hex =
    case decodeFullAnnotatorFromHexText
        (natVersion @11)
        "Conway transaction"
        conwayTxDecoder
        (T.strip hex) of
        Left err -> Left (T.pack (show err))
        Right tx -> Right tx

conwayTxDecoder :: forall s. Decoder s (Annotator ConwayTx)
conwayTxDecoder = decCBOR

referenceInputOutrefs :: ConwayTx -> [T.Text]
referenceInputOutrefs tx =
    map txInOutref $
        Set.toAscList $
            tx ^. (Core.bodyTxL . L.referenceInputsTxBodyL)

producerInputScriptHashes :: ProducerContext -> Map.Map T.Text T.Text
producerInputScriptHashes (ProducerContext producers) =
    Map.fromList $
        concatMap producerOutputs (Map.toList producers)
  where
    producerOutputs (txId, ProducerTx (Right tx)) =
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
    :: ConwayTx -> Aeson.Value -> Aeson.Value
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

typedMetadataEntries :: ConwayTx -> [Aeson.Value]
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
