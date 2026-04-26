{-# LANGUAGE DataKinds #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

{- | Conway transaction inspector.

  Decoder-only: no signature checking, no script evaluation, no fee
  validation. The hard work (CBOR → Conway `Tx`) is delegated to the
  upstream Haskell ledger packages. Browser-facing calls use a small
  ledger-operation envelope so each UI interaction can go back through
  the ledger value instead of navigating a stale client-side JSON
  projection.
-}
module Conway.Inspector (
    inspect,
    runLedgerOperationInput,
    InspectError (..),
) where

import qualified Cardano.Crypto.Hash as Crypto
import qualified Cardano.Ledger.Address as Addr
import qualified Cardano.Ledger.Api as L
import qualified Cardano.Ledger.BaseTypes as BaseTypes
import qualified Cardano.Ledger.Binary as Binary
import qualified Cardano.Ledger.Coin as Coin
import qualified Cardano.Ledger.Conway as Conway
import qualified Cardano.Ledger.Conway.Scripts as ConwayScripts
import Cardano.Ledger.Core (TxLevel (..))
import qualified Cardano.Ledger.Core as Core
import qualified Cardano.Ledger.Hashes as Hashes
import qualified Cardano.Ledger.Keys as Keys
import qualified Cardano.Ledger.Mary.Value as Mary
import qualified Cardano.Ledger.Plutus.Data as PData
import qualified Cardano.Ledger.Plutus.ExUnits as ExUnits
import qualified Cardano.Ledger.TxIn as TxIn
import Control.Monad ((>=>))
import Data.Aeson ((.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Lazy as BSL
import qualified Data.ByteString.Short as SBS
import Data.Foldable (toList)
import Data.List (foldl', stripPrefix)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, isJust)
import qualified Data.Set as Set
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import Lens.Micro ((^.))
import Text.Read (readMaybe)

data InspectError
    = MalformedHex String
    | MalformedCbor String
    | MalformedLedgerOperation String
    | UnknownLedgerOperation T.Text
    deriving (Show)

data LedgerOperationRequest = LedgerOperationRequest
    { lorTxCbor :: T.Text
    , lorOperation :: T.Text
    , lorArgs :: Aeson.Value
    , lorPath :: [T.Text]
    }

instance Aeson.FromJSON LedgerOperationRequest where
    parseJSON = Aeson.withObject "LedgerOperationRequest" $ \o -> do
        txCbor <- o Aeson..: "tx_cbor"
        operation <- parseOperation o
        legacyPath <- o Aeson..:? "path" Aeson..!= []
        args <- o Aeson..:? "args" Aeson..!= Aeson.object []
        path <- parsePathArg args legacyPath
        pure
            LedgerOperationRequest
                { lorTxCbor = txCbor
                , lorOperation = normalizeOperation operation
                , lorArgs = args
                , lorPath = path
                }
      where
        parseOperation o = do
            maybeOp <- o Aeson..:? "op"
            case maybeOp of
                Just op -> pure op
                Nothing -> do
                    maybeMethod <- o Aeson..:? "method"
                    case maybeMethod of
                        Just method -> pure method
                        Nothing -> fail "missing required field: op"

        parsePathArg args legacyPath =
            case args of
                Aeson.Object obj ->
                    case KeyMap.lookup "path" obj of
                        Just pathValue -> Aeson.parseJSON pathValue
                        Nothing -> pure legacyPath
                _ -> pure legacyPath

        normalizeOperation "inspect" = "tx.inspect"
        normalizeOperation "browse" = "tx.browse"
        normalizeOperation "identify" = "tx.identify"
        normalizeOperation "witness.plan" = "tx.witness.plan"
        normalizeOperation op = op

-- | Hex → bytes → Conway tx → JSON.
inspect :: BS.ByteString -> Either InspectError Aeson.Value
inspect hexBytes = do
    tx <- decodeTx hexBytes
    pure (renderTx tx)

{- | Browser/runtime ledger operation. If stdin is not a JSON operation request,
  fall back to the legacy raw-CBOR inspection path used by CLI recipes.
-}
runLedgerOperationInput :: BS.ByteString -> Either InspectError Aeson.Value
runLedgerOperationInput input =
    case Aeson.eitherDecodeStrict' input of
        Right request -> runLedgerOperation request
        Left err
            | looksLikeJsonRequest input -> Left (MalformedLedgerOperation err)
            | otherwise -> inspect input

looksLikeJsonRequest :: BS.ByteString -> Bool
looksLikeJsonRequest input =
    case BS.dropWhile isJsonWhitespace input of
        bs | BS.null bs -> False
        bs -> BS.head bs == 0x7b
  where
    isJsonWhitespace c = c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d

runLedgerOperation :: LedgerOperationRequest -> Either InspectError Aeson.Value
runLedgerOperation request = do
    (txBytes, tx) <- decodeTxWithBytes (T.encodeUtf8 (lorTxCbor request))
    case lorOperation request of
        "tx.inspect" ->
            pure $
                ledgerOperationResponse
                    (lorOperation request)
                    [ "inspection" .= renderTx tx
                    , "browser" .= browserJson tx (lorPath request)
                    ]
        "tx.browse" ->
            pure $
                ledgerOperationResponse
                    (lorOperation request)
                    [ "browser" .= browserJson tx (lorPath request)
                    ]
        "tx.identify" ->
            pure $
                ledgerOperationResponse
                    (lorOperation request)
                    [ "identification" .= identifyJson txBytes tx
                    ]
        "tx.witness.plan" ->
            pure $
                ledgerOperationResponse
                    (lorOperation request)
                    [ "witness_plan" .= witnessPlanJson (lorArgs request) tx
                    ]
        other -> Left (UnknownLedgerOperation other)

ledgerOperationResponse :: T.Text -> [(AesonKey.Key, Aeson.Value)] -> Aeson.Value
ledgerOperationResponse operation resultFields =
    Aeson.object
        [ "ledger_functional_layer" .= ("cardano-ledger-functional/v1" :: T.Text)
        , "op" .= operation
        , "result" .= Aeson.object resultFields
        ]

decodeTx ::
    BS.ByteString ->
    Either InspectError (L.Tx TopTx Conway.ConwayEra)
decodeTx =
    fmap snd . decodeTxWithBytes

decodeTxWithBytes ::
    BS.ByteString ->
    Either InspectError (BS.ByteString, L.Tx TopTx Conway.ConwayEra)
decodeTxWithBytes hexBytes = do
    txBytes <- hexDecode hexBytes
    tx <- decodeConway (BSL.fromStrict txBytes)
    pure (txBytes, tx)

hexDecode :: BS.ByteString -> Either InspectError BS.ByteString
hexDecode bs =
    case B16.decode (BS.filter (not . isHexWhitespace) bs) of
        Left err -> Left (MalformedHex err)
        Right ok -> Right ok
  where
    isHexWhitespace c = c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d

decodeConway :: BSL.ByteString -> Either InspectError (L.Tx TopTx Conway.ConwayEra)
decodeConway bs =
    case Binary.decodeFullAnnotator (Binary.natVersion @11) "Tx" Binary.decCBOR bs of
        Left err -> Left (MalformedCbor (show err))
        Right tx -> Right tx

browserJson ::
    L.Tx TopTx Conway.ConwayEra ->
    [T.Text] ->
    Aeson.Value
browserJson tx requestedPath =
    let root = renderTx tx
        current = valueAt root requestedPath
        path = if current == Nothing then [] else requestedPath
        value = fromMaybe root current
        breadcrumbs = breadcrumbsFor path
        currentLabel = case reverse breadcrumbs of
            Aeson.Object crumb : _ ->
                case KeyMap.lookup "label" crumb of
                    Just (Aeson.String label) -> label
                    _ -> "tx"
            _ -> "tx"
        kind = kindOf value
     in Aeson.object
            [ "valid" .= True
            , "title" .= currentLabel
            , "subtitle"
                .= if kind == "array" || kind == "object"
                    then kind <> " / " <> valueSummary value
                    else kind
            , "currentPath" .= encodePath path
            , "currentJson" .= copyText value
            , "breadcrumbs" .= breadcrumbs
            , "rows" .= browserRows path value
            ]

valueAt :: Aeson.Value -> [T.Text] -> Maybe Aeson.Value
valueAt = foldl step . Just
  where
    step Nothing _ = Nothing
    step (Just (Aeson.Object o)) key =
        KeyMap.lookup (AesonKey.fromText key) o
    step (Just (Aeson.Array a)) key = do
        ix <- pathIndex key
        listAt ix (toList a)
    step _ _ = Nothing

listAt :: Int -> [a] -> Maybe a
listAt index xs
    | index < 0 = Nothing
    | otherwise = case drop index xs of
        value : _ -> Just value
        [] -> Nothing

pathIndex :: T.Text -> Maybe Int
pathIndex =
    stripPrefix "#" . T.unpack >=> readMaybe

kindOf :: Aeson.Value -> T.Text
kindOf Aeson.Null = "null"
kindOf (Aeson.Bool _) = "boolean"
kindOf (Aeson.Number _) = "number"
kindOf (Aeson.String _) = "string"
kindOf (Aeson.Array _) = "array"
kindOf (Aeson.Object _) = "object"

valueSummary :: Aeson.Value -> T.Text
valueSummary (Aeson.Array a) =
    plural (length (toList a)) "item"
valueSummary (Aeson.Object o) =
    plural (length (KeyMap.toList o)) "field"
valueSummary (Aeson.String t) =
    shortText t
valueSummary Aeson.Null =
    "null"
valueSummary value =
    copyText value

plural :: Int -> T.Text -> T.Text
plural n label =
    T.pack (show n) <> " " <> label <> if n == 1 then "" else "s"

shortText :: T.Text -> T.Text
shortText text =
    let limit = 56
     in if T.length text <= limit
            then text
            else T.take 40 text <> "..." <> T.takeEnd 12 text

copyText :: Aeson.Value -> T.Text
copyText (Aeson.String t) = t
copyText value =
    T.decodeUtf8 (BSL.toStrict (Aeson.encode value))

browserRows :: [T.Text] -> Aeson.Value -> [Aeson.Value]
browserRows parentPath (Aeson.Array a) =
    [ browserRow parentPath (T.pack ("#" <> show ix)) child
    | (ix, child) <- zip [0 :: Int ..] (toList a)
    ]
browserRows parentPath (Aeson.Object o) =
    [ browserRow parentPath (AesonKey.toText key) child
    | (key, child) <- KeyMap.toList o
    ]
browserRows _ _ =
    []

browserRow :: [T.Text] -> T.Text -> Aeson.Value -> Aeson.Value
browserRow parentPath label value =
    let path = parentPath <> [label]
     in Aeson.object
            [ "label" .= label
            , "path" .= encodePath path
            , "kind" .= kindOf value
            , "summary" .= valueSummary value
            , "copyValue" .= copyText value
            , "canDive" .= isContainer value
            ]

isContainer :: Aeson.Value -> Bool
isContainer (Aeson.Array _) = True
isContainer (Aeson.Object _) = True
isContainer _ = False

breadcrumbsFor :: [T.Text] -> [Aeson.Value]
breadcrumbsFor path =
    Aeson.object
        [ "label" .= ("tx" :: T.Text)
        , "path" .= encodePath []
        ]
        : [ Aeson.object
            [ "label" .= label
            , "path" .= encodePath (take n path)
            ]
          | (n, label) <- zip [1 :: Int ..] path
          ]

encodePath :: [T.Text] -> T.Text
encodePath path =
    T.decodeUtf8 (BSL.toStrict (Aeson.encode path))

identifyJson ::
    BS.ByteString ->
    L.Tx TopTx Conway.ConwayEra ->
    Aeson.Value
identifyJson txBytes tx =
    let body = tx ^. L.bodyTxL
        wits = tx ^. Core.witsTxL
        scripts = Map.elems (wits ^. Core.scriptTxWitsL)
        (nativeScripts, plutusV1, plutusV2, plutusV3) =
            scriptWitnessCounts scripts
        inputs = toList (body ^. L.inputsTxBodyL)
        refIns = toList (body ^. L.referenceInputsTxBodyL)
        outputs = toList (body ^. L.outputsTxBodyL)
        certs = toList (body ^. L.certsTxBodyL)
        withdrawals = body ^. L.withdrawalsTxBodyL
        reqSigners = toList (body ^. L.reqSignerHashesTxBodyL)
     in Aeson.object
            [ "era" .= ("Conway" :: T.Text)
            , "tx_id" .= txIdHex (Core.txIdTx tx)
            , "body_hash" .= txIdHex (Core.txIdTxBody body)
            , "tx_size_bytes" .= BS.length txBytes
            , "fee_lovelace" .= T.pack (show (Coin.unCoin (body ^. L.feeTxBodyL)))
            , "input_count" .= length inputs
            , "reference_input_count" .= length refIns
            , "output_count" .= length outputs
            , "cert_count" .= length certs
            , "withdrawal_count" .= withdrawalsCount withdrawals
            , "required_signer_count" .= length reqSigners
            , "witness_counts"
                .= Aeson.object
                    [ "vkey" .= Set.size (wits ^. Core.addrTxWitsL)
                    , "bootstrap" .= Set.size (wits ^. Core.bootAddrTxWitsL)
                    , "native_script" .= nativeScripts
                    , "plutus_v1" .= plutusV1
                    , "plutus_v2" .= plutusV2
                    , "plutus_v3" .= plutusV3
                    , "redeemer" .= Map.size (L.unRedeemers (wits ^. L.rdmrsTxWitsL))
                    , "datum" .= Map.size (L.unTxDats (wits ^. L.datsTxWitsL))
                    ]
            ]

witnessPlanJson ::
    Aeson.Value ->
    L.Tx TopTx Conway.ConwayEra ->
    Aeson.Value
witnessPlanJson args tx =
    let body = tx ^. L.bodyTxL
        wits = tx ^. Core.witsTxL
        context = producerContextFromArgs args
        inputPolicy = inputPolicyFromArgs args
        inputs = toList (body ^. L.inputsTxBodyL)
        referenceInputs =
            toList (body ^. L.referenceInputsTxBodyL)
        requiredSignerHexes =
            keyHashHex <$> toList (body ^. L.reqSignerHashesTxBodyL)
        presentVKeyHexes =
            keyHashHex . Keys.witVKeyHash <$> toList (wits ^. Core.addrTxWitsL)
        presentBootstrapHexes =
            keyHashHex . Keys.bootstrapWitKeyHash
                <$> toList (wits ^. Core.bootAddrTxWitsL)
        presentSignerHexSet =
            Set.fromList (presentVKeyHexes <> presentBootstrapHexes)
        missingSignerHexes =
            filter (`Set.notMember` presentSignerHexSet) requiredSignerHexes
        scriptWitnesses =
            Map.toList (wits ^. Core.scriptTxWitsL)
        redeemers =
            Map.toList (L.unRedeemers (wits ^. L.rdmrsTxWitsL))
        datums =
            Map.toList (L.unTxDats (wits ^. L.datsTxWitsL))
        missingContextInputs =
            missingContextTxIns context inputs
        missingContextReferenceInputs =
            missingContextTxIns context referenceInputs
        warnings =
            contextWarnings
                context
                missingContextInputs
                missingContextReferenceInputs
                : if null missingSignerHexes
                    then []
                    else
                        [ "Declared required signer hashes are absent from the witness set." ::
                            T.Text
                        ]
     in Aeson.object
            [ "required_signers" .= map requiredSignerJson requiredSignerHexes
            , "present_vkey_witnesses"
                .= map presentVKeyWitnessJson presentVKeyHexes
            , "present_bootstrap_witnesses"
                .= map presentBootstrapWitnessJson presentBootstrapHexes
            , "missing_vkey_witnesses"
                .= map missingSignerJson missingSignerHexes
            , "scripts" .= map scriptWitnessJson scriptWitnesses
            , "redeemers" .= map redeemerJson redeemers
            , "datums" .= map datumWitnessJson datums
            , "reference_inputs" .= map txInJson referenceInputs
            , "resolved_inputs"
                .= map (resolvedTxInJson context) inputs
            , "resolved_reference_inputs"
                .= map (resolvedTxInJson context) referenceInputs
            , "context"
                .= contextSummaryJson
                    inputPolicy
                    context
                    inputs
                    referenceInputs
                    missingContextInputs
                    missingContextReferenceInputs
            , "summary"
                .= Aeson.object
                    [ "required_signer_count" .= length requiredSignerHexes
                    , "present_vkey_witness_count" .= length presentVKeyHexes
                    , "present_bootstrap_witness_count" .= length presentBootstrapHexes
                    , "missing_vkey_witness_count" .= length missingSignerHexes
                    , "script_count" .= length scriptWitnesses
                    , "redeemer_count" .= length redeemers
                    , "datum_count" .= length datums
                    , "reference_input_count" .= length referenceInputs
                    ]
            , "warnings" .= warnings
            ]

transactionOnlyWitnessPlanWarning :: T.Text
transactionOnlyWitnessPlanWarning =
    "Transaction-only witness plan: producer transaction CBOR was not supplied, so input address credentials, reference scripts, and datum requirements cannot be inferred."

partialProducerContextWarning :: T.Text
partialProducerContextWarning =
    "Producer transaction context was supplied but does not resolve every transaction input."

completeProducerContextWarning :: T.Text
completeProducerContextWarning =
    "Producer transaction CBOR resolved every visible transaction input; live unspent status is not checked by this operation."

contextWarnings ::
    ProducerContext ->
    [TxIn.TxIn] ->
    [TxIn.TxIn] ->
    T.Text
contextWarnings context missingInputs missingReferenceInputs
    | not (producerContextSupplied context) = transactionOnlyWitnessPlanWarning
    | null missingInputs && null missingReferenceInputs = completeProducerContextWarning
    | otherwise = partialProducerContextWarning

data ProducerContext = ProducerContext
    { pcProducerTxs :: Map.Map T.Text ProducerTx
    , ucResolution :: Maybe Aeson.Value
    }

data ProducerTx = ProducerTx
    { ptSource :: T.Text
    , ptDecoded :: Either T.Text (L.Tx TopTx Conway.ConwayEra)
    }

producerContextFromArgs :: Aeson.Value -> ProducerContext
producerContextFromArgs args =
    ProducerContext
        { pcProducerTxs =
            case argsObject args
                >>= lookupObjectValue "context"
                >>= lookupValue "producer_txs" of
                Just (Aeson.Object producerTxs) ->
                    Map.fromList
                        [ ( AesonKey.toText key
                          , producerTxFromValue value
                          )
                        | (key, value) <- KeyMap.toList producerTxs
                        ]
                _ -> Map.empty
        , ucResolution =
            argsObject args
                >>= lookupObjectValue "context"
                >>= lookupValue "resolution"
        }

producerTxFromValue :: Aeson.Value -> ProducerTx
producerTxFromValue value =
    let source =
            case lookupValue "source" value of
                Just (Aeson.String s) -> s
                _ -> "context.producer_txs"
     in ProducerTx
            { ptSource = source
            , ptDecoded =
                case producerTxCbor value of
                    Nothing -> Left "producer transaction is missing tx_cbor"
                    Just txCbor ->
                        case decodeTx (T.encodeUtf8 txCbor) of
                            Left err -> Left (inspectErrorText err)
                            Right tx -> Right tx
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

inspectErrorText :: InspectError -> T.Text
inspectErrorText =
    T.pack . show

producerContextSupplied :: ProducerContext -> Bool
producerContextSupplied =
    not . Map.null . pcProducerTxs

inputPolicyFromArgs :: Aeson.Value -> T.Text
inputPolicyFromArgs args =
    case argsObject args >>= lookupObjectValue "input_policy" of
        Just (Aeson.String policy) -> policy
        _ -> "preserve"

missingContextTxIns :: ProducerContext -> [TxIn.TxIn] -> [TxIn.TxIn]
missingContextTxIns context =
    filter (not . isJust . producerTxOutput context)

contextSummaryJson ::
    T.Text ->
    ProducerContext ->
    [TxIn.TxIn] ->
    [TxIn.TxIn] ->
    [TxIn.TxIn] ->
    [TxIn.TxIn] ->
    Aeson.Value
contextSummaryJson
    inputPolicy
    context
    inputs
    referenceInputs
    missingInputs
    missingReferenceInputs =
        let supplied = producerContextSupplied context
            resolvedInputs =
                length inputs - length missingInputs
            resolvedReferenceInputs =
                length referenceInputs - length missingReferenceInputs
         in Aeson.object
                [ "input_policy" .= inputPolicy
                , "producer_tx_count" .= Map.size (pcProducerTxs context)
                , "decoded_producer_tx_count" .= decodedProducerTxCount context
                , "producer_tx_errors" .= producerTxErrors context
                , "supplied" .= supplied
                , "complete"
                    .= (supplied && null missingInputs && null missingReferenceInputs)
                , "input_count" .= length inputs
                , "resolved_input_count" .= resolvedInputs
                , "missing_input_count" .= length missingInputs
                , "reference_input_count" .= length referenceInputs
                , "resolved_reference_input_count" .= resolvedReferenceInputs
                , "missing_reference_input_count" .= length missingReferenceInputs
                , "resolution" .= fromMaybe Aeson.Null (ucResolution context)
                ]

decodedProducerTxCount :: ProducerContext -> Int
decodedProducerTxCount context =
    length
        [ ()
        | ProducerTx{ptDecoded = Right _} <- Map.elems (pcProducerTxs context)
        ]

producerTxErrors :: ProducerContext -> [Aeson.Value]
producerTxErrors context =
    [ Aeson.object
        [ "tx_id" .= txId
        , "error" .= err
        ]
    | (txId, ProducerTx{ptDecoded = Left err}) <-
        Map.toList (pcProducerTxs context)
    ]

resolvedTxInJson :: ProducerContext -> TxIn.TxIn -> Aeson.Value
resolvedTxInJson context txIn =
    let key = txInKey txIn
        baseFields =
            [ "key" .= key
            , "tx_id" .= txInTxIdHex txIn
            , "index" .= txInIndex txIn
            ]
     in case producerTxLookup context txIn of
            Nothing ->
                Aeson.object $
                    baseFields
                        <> [ "resolved" .= False
                           , "reason" .= ("producer transaction CBOR not supplied" :: T.Text)
                           ]
            Just (ProducerTx{ptDecoded = Left err}) ->
                Aeson.object $
                    baseFields
                        <> [ "resolved" .= False
                           , "source" .= ("context.producer_txs" :: T.Text)
                           , "reason" .= err
                           ]
            Just producerTx@ProducerTx{ptDecoded = Right producer} ->
                case producerOutputAt txIn producer of
                    Nothing ->
                        Aeson.object $
                            baseFields
                                <> [ "resolved" .= False
                                   , "source" .= ptSource producerTx
                                   , "reason" .= ("producer transaction output index not found" :: T.Text)
                                   ]
                    Just txOut ->
                        Aeson.object $
                            baseFields
                                <> [ "resolved" .= True
                                   , "source" .= ptSource producerTx
                                   , "tx_out" .= txOutJson txOut
                                   ]

producerTxLookup :: ProducerContext -> TxIn.TxIn -> Maybe ProducerTx
producerTxLookup context txIn =
    Map.lookup (txInTxIdHex txIn) (pcProducerTxs context)

producerTxOutput ::
    ProducerContext ->
    TxIn.TxIn ->
    Maybe (L.TxOut Conway.ConwayEra)
producerTxOutput context txIn = do
    ProducerTx{ptDecoded = Right producer} <- producerTxLookup context txIn
    producerOutputAt txIn producer

producerOutputAt ::
    TxIn.TxIn ->
    L.Tx TopTx Conway.ConwayEra ->
    Maybe (L.TxOut Conway.ConwayEra)
producerOutputAt txIn producer =
    listAt (txInIndex txIn) $
        toList ((producer ^. L.bodyTxL) ^. L.outputsTxBodyL)

argsObject :: Aeson.Value -> Maybe Aeson.Object
argsObject (Aeson.Object obj) = Just obj
argsObject _ = Nothing

lookupValue :: AesonKey.Key -> Aeson.Value -> Maybe Aeson.Value
lookupValue key (Aeson.Object obj) =
    KeyMap.lookup key obj
lookupValue _ _ =
    Nothing

lookupObjectValue :: AesonKey.Key -> Aeson.Object -> Maybe Aeson.Value
lookupObjectValue =
    KeyMap.lookup

requiredSignerJson :: T.Text -> Aeson.Value
requiredSignerJson signerHash =
    Aeson.object
        [ "hash" .= signerHash
        , "source" .= ("tx_body.required_signers" :: T.Text)
        ]

presentVKeyWitnessJson :: T.Text -> Aeson.Value
presentVKeyWitnessJson signerHash =
    Aeson.object
        [ "hash" .= signerHash
        , "source" .= ("witness_set.vkey" :: T.Text)
        ]

presentBootstrapWitnessJson :: T.Text -> Aeson.Value
presentBootstrapWitnessJson signerHash =
    Aeson.object
        [ "hash" .= signerHash
        , "source" .= ("witness_set.bootstrap" :: T.Text)
        ]

missingSignerJson :: T.Text -> Aeson.Value
missingSignerJson signerHash =
    Aeson.object
        [ "hash" .= signerHash
        , "reason"
            .= ( "declared required signer not present in vkey or bootstrap witnesses" ::
                    T.Text
               )
        ]

scriptWitnessJson ::
    (Hashes.ScriptHash, ConwayScripts.AlonzoScript Conway.ConwayEra) ->
    Aeson.Value
scriptWitnessJson (scriptHash, script) =
    Aeson.object
        [ "hash" .= scriptHashHex scriptHash
        , "language" .= scriptWitnessLanguage script
        , "source" .= ("witness_set.scripts" :: T.Text)
        ]

scriptWitnessLanguage ::
    ConwayScripts.AlonzoScript Conway.ConwayEra ->
    T.Text
scriptWitnessLanguage = \case
    ConwayScripts.NativeScript _ -> "native_script"
    ConwayScripts.PlutusScript plutusScript ->
        case plutusScript of
            ConwayScripts.ConwayPlutusV1 _ -> "plutus_v1"
            ConwayScripts.ConwayPlutusV2 _ -> "plutus_v2"
            ConwayScripts.ConwayPlutusV3 _ -> "plutus_v3"

redeemerJson ::
    ( L.PlutusPurpose L.AsIx Conway.ConwayEra
    , (PData.Data Conway.ConwayEra, ExUnits.ExUnits)
    ) ->
    Aeson.Value
redeemerJson (purpose, (redeemerData, exUnits)) =
    Aeson.object
        [ "purpose" .= T.pack (show purpose)
        , "redeemer_data_hash" .= safeHashHex (PData.hashData redeemerData)
        , "ex_units" .= Aeson.toJSON exUnits
        ]

datumWitnessJson ::
    (Hashes.DataHash, PData.Data Conway.ConwayEra) ->
    Aeson.Value
datumWitnessJson (dataHash, datumValue) =
    Aeson.object
        [ "hash" .= safeHashHex dataHash
        , "computed_hash" .= safeHashHex (PData.hashData datumValue)
        , "source" .= ("witness_set.datums" :: T.Text)
        ]

scriptWitnessCounts ::
    [ConwayScripts.AlonzoScript Conway.ConwayEra] ->
    (Int, Int, Int, Int)
scriptWitnessCounts =
    foldl' step (0, 0, 0, 0)
  where
    step (nativeN, v1N, v2N, v3N) = \case
        ConwayScripts.NativeScript _ ->
            (nativeN + 1, v1N, v2N, v3N)
        ConwayScripts.PlutusScript plutusScript ->
            case plutusScript of
                ConwayScripts.ConwayPlutusV1 _ ->
                    (nativeN, v1N + 1, v2N, v3N)
                ConwayScripts.ConwayPlutusV2 _ ->
                    (nativeN, v1N, v2N + 1, v3N)
                ConwayScripts.ConwayPlutusV3 _ ->
                    (nativeN, v1N, v2N, v3N + 1)

renderTx :: L.Tx TopTx Conway.ConwayEra -> Aeson.Value
renderTx tx =
    let body = tx ^. L.bodyTxL
        inputs = toList (body ^. L.inputsTxBodyL)
        refIns = toList (body ^. L.referenceInputsTxBodyL)
        outputs = toList (body ^. L.outputsTxBodyL)
        fee = body ^. L.feeTxBodyL
        vldt = body ^. L.vldtTxBodyL
        mint = body ^. L.mintTxBodyL
        certs = toList (body ^. L.certsTxBodyL)
        withdrawals = body ^. L.withdrawalsTxBodyL
        reqSigners = toList (body ^. L.reqSignerHashesTxBodyL)
     in Aeson.Object $
            KeyMap.fromList
                [ "era" .= ("Conway" :: T.Text)
                , "decoder" .= ("cardano-ledger-conway + cardano-ledger-binary (wasm32-wasi, GHC 9.12)" :: T.Text)
                , "fee_lovelace" .= T.pack (show (Coin.unCoin fee))
                , "validity_interval" .= validityJson vldt
                , "input_count" .= length inputs
                , "reference_input_count" .= length refIns
                , "output_count" .= length outputs
                , "cert_count" .= length certs
                , "withdrawal_count" .= withdrawalsCount withdrawals
                , "required_signer_count" .= length reqSigners
                , "inputs" .= map txInJson inputs
                , "reference_inputs" .= map txInJson refIns
                , "outputs" .= map txOutJson outputs
                , "mint" .= multiAssetJson mint
                ]

validityJson :: L.ValidityInterval -> Aeson.Value
validityJson (L.ValidityInterval before hereafter) =
    Aeson.object
        [ "invalid_before" .= renderSlot before
        , "invalid_hereafter" .= renderSlot hereafter
        ]
  where
    renderSlot :: BaseTypes.StrictMaybe BaseTypes.SlotNo -> Aeson.Value
    renderSlot BaseTypes.SNothing = Aeson.Null
    renderSlot (BaseTypes.SJust s) = Aeson.toJSON (T.pack (show (BaseTypes.unSlotNo s)))

{- | Withdrawals are wrapped in a newtype; reach into the Map and count.
  Ledger versions differ on the exact constructor / accessor; use Show
  to bootstrap — replaceable with a proper accessor later.
-}
withdrawalsCount :: L.Withdrawals -> Int
withdrawalsCount (L.Withdrawals m) = Map.size m

-- | Render a Conway TxOut with address, value (coin + assets), and datum.
txOutJson :: L.TxOut Conway.ConwayEra -> Aeson.Value
txOutJson txOut =
    let value = txOut ^. L.valueTxOutL
        Mary.MaryValue c m = value
     in Aeson.object
            [ "address_hex" .= T.decodeUtf8 (B16.encode (Addr.serialiseAddr (txOut ^. L.addrTxOutL)))
            , "coin_lovelace" .= T.pack (show (Coin.unCoin c))
            , "assets" .= multiAssetJson m
            , "datum" .= datumJson (txOut ^. L.datumTxOutL)
            ]

multiAssetJson :: Mary.MultiAsset -> Aeson.Value
multiAssetJson (Mary.MultiAsset m) =
    Aeson.Object $
        KeyMap.fromList
            [ ( AesonKey.fromText (policyHex pid)
              , Aeson.Object $
                    KeyMap.fromList
                        [ ( AesonKey.fromText (assetNameHex an)
                          , Aeson.String (T.pack (show q))
                          )
                        | (an, q) <- Map.toList assetMap
                        ]
              )
            | (pid, assetMap) <- Map.toList m
            ]
  where
    policyHex :: Mary.PolicyID -> T.Text
    policyHex (Mary.PolicyID (Hashes.ScriptHash h)) =
        T.decodeUtf8 (B16.encode (Crypto.hashToBytes h))
    assetNameHex :: Mary.AssetName -> T.Text
    assetNameHex (Mary.AssetName sbs) = T.decodeUtf8 (B16.encode (SBS.fromShort sbs))

-- | Render TxOut datum state. The ledger's `Datum era` is three-cased.
datumJson :: PData.Datum Conway.ConwayEra -> Aeson.Value
datumJson PData.NoDatum =
    Aeson.object ["kind" .= ("no_datum" :: T.Text)]
datumJson (PData.DatumHash h) =
    Aeson.object
        [ "kind" .= ("datum_hash" :: T.Text)
        , "hash" .= T.decodeUtf8 (B16.encode (Crypto.hashToBytes (Hashes.extractHash h)))
        ]
datumJson (PData.Datum _) =
    Aeson.object
        [ "kind" .= ("inline_datum" :: T.Text)
        , "note" .= ("Plutus Data AST rendering deferred" :: T.Text)
        ]

txInJson :: TxIn.TxIn -> Aeson.Value
txInJson (TxIn.TxIn (TxIn.TxId safeHash) (BaseTypes.TxIx ix)) =
    Aeson.object
        [ "tx_id" .= hashHex (Hashes.extractHash safeHash)
        , "index" .= fromEnum ix
        ]

txInKey :: TxIn.TxIn -> T.Text
txInKey txIn =
    txInTxIdHex txIn <> "#" <> T.pack (show (txInIndex txIn))

txInTxIdHex :: TxIn.TxIn -> T.Text
txInTxIdHex (TxIn.TxIn (TxIn.TxId safeHash) _) =
    hashHex (Hashes.extractHash safeHash)

txInIndex :: TxIn.TxIn -> Int
txInIndex (TxIn.TxIn _ (BaseTypes.TxIx ix)) =
    fromEnum ix

txIdHex :: TxIn.TxId -> T.Text
txIdHex (TxIn.TxId safeHash) =
    hashHex (Hashes.extractHash safeHash)

keyHashHex :: Hashes.KeyHash r -> T.Text
keyHashHex (Hashes.KeyHash h) =
    hashHex h

scriptHashHex :: Hashes.ScriptHash -> T.Text
scriptHashHex (Hashes.ScriptHash h) =
    hashHex h

safeHashHex :: Hashes.SafeHash i -> T.Text
safeHashHex safeHash =
    hashHex (Hashes.extractHash safeHash)

hashHex :: Crypto.Hash h a -> T.Text
hashHex =
    T.decodeUtf8 . B16.encode . Crypto.hashToBytes
