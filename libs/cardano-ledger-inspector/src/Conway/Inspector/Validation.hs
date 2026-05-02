{-# LANGUAGE DataKinds #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

{- | Conway transaction validation backed by upstream ledger applyTx.

  The operation builds the minimal ledger environment from explicit caller
  context and reports the ledger predicates returned by the Conway rules.
-}
module Conway.Inspector.Validation (
    validateTxJson,
) where

import qualified Cardano.Ledger.Api as L
import qualified Cardano.Ledger.BaseTypes as BaseTypes
import qualified Cardano.Ledger.Conway as Conway
import qualified Cardano.Ledger.Conway.Rules as ConwayRules
import Cardano.Ledger.Core (TxLevel (..))
import qualified Cardano.Ledger.Core as Core
import qualified Cardano.Ledger.Shelley.API.Mempool as Mempool
import qualified Cardano.Ledger.Shelley.LedgerState as ShelleyState
import qualified Cardano.Ledger.TxIn as TxIn
import qualified Cardano.Slotting.EpochInfo as EpochInfo
import qualified Cardano.Slotting.Time as SlottingTime
import Conway.Inspector.Common (
    argsObject,
    lookupObjectValue,
    lookupValue,
    txIdHex,
    txInIndex,
    txInKey,
    txInTxIdHex,
    txOutJson,
    withdrawalsCount,
 )
import Conway.Inspector.Context (
    ProducerContext (..),
    ProducerTx (..),
    decodedProducerTxCount,
    inputPolicyFromArgs,
    missingContextTxIns,
    producerContextFromArgs,
    producerContextSupplied,
    producerOutputAt,
    producerTxErrors,
    producerTxLookup,
    producerTxOutput,
 )
import Data.Aeson ((.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AesonKey
import qualified Data.ByteString as BS
import Data.Default (def)
import Data.Foldable (toList)
import Data.Function ((&))
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, isNothing)
import Data.Ratio ((%))
import qualified Data.Text as T
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Data.Word (Word64)
import Lens.Micro ((.~), (^.))
import Text.Read (readMaybe)

data LedgerApplyResult
    = LedgerApplyNotEvaluated T.Text
    | LedgerApplyAccepted
    | LedgerApplyRejected [Aeson.Value]

validateTxJson ::
    BS.ByteString ->
    Aeson.Value ->
    L.Tx TopTx Conway.ConwayEra ->
    Aeson.Value
validateTxJson _txBytes args tx =
    let body = tx ^. L.bodyTxL
        context = producerContextFromArgs args
        inputPolicy = inputPolicyFromArgs args
        contextValue = argsObject args >>= lookupObjectValue "context"
        inputs = toList (body ^. L.inputsTxBodyL)
        referenceInputs = toList (body ^. L.referenceInputsTxBodyL)
        unresolvedInputs = missingContextTxIns context inputs
        unresolvedReferenceInputs = missingContextTxIns context referenceInputs
        missingProducerInputs = filter (isNothing . producerTxLookup context) inputs
        missingProducerReferenceInputs =
            filter (isNothing . producerTxLookup context) referenceInputs
        (network, networkMissing, networkErrors) =
            requiredContextField
                "network"
                "network"
                "Supply the network for ledger validation."
                parseNetworkValue
                contextValue
        (slot, slotMissing, slotErrors) =
            requiredContextField
                "slot"
                "slot"
                "Supply the current slot for ledger validation."
                (parseWord64Value "slot")
                contextValue
        (epoch, epochMissing, epochErrors) =
            requiredContextField
                "epoch"
                "epoch"
                "Supply the current epoch for ledger validation."
                (parseWord64Value "epoch")
                contextValue
        (pparams, pparamsMissing, pparamsErrors) =
            requiredContextField
                "protocol_parameters"
                "protocol_parameters"
                "Supply a complete Conway protocol-parameter object."
                parseProtocolParametersValue
                contextValue
        contextErrors =
            inputPolicyErrors inputPolicy
                <> unsupportedUtxoJsonErrors contextValue
                <> producerDecodeContextErrors context
                <> producerTxIdContextErrors context
                <> producerOutputIndexContextErrors
                    "input"
                    "inputs"
                    context
                    inputs
                <> producerOutputIndexContextErrors
                    "reference_input"
                    "reference_inputs"
                    context
                    referenceInputs
                <> networkErrors
                <> slotErrors
                <> epochErrors
                <> pparamsErrors
        baseMissingContext =
            zipWith
                (missingSourceOutputContextJson "input" "inputs")
                [0 :: Int ..]
                missingProducerInputs
                <> zipWith
                    (missingSourceOutputContextJson "reference_input" "reference_inputs")
                    [0 :: Int ..]
                    missingProducerReferenceInputs
                <> networkMissing
                <> slotMissing
                <> epochMissing
                <> pparamsMissing
                <> unsupportedFeatureMissingContext body
        ledgerApplyResult =
            runLedgerApplyTx
                contextErrors
                baseMissingContext
                network
                slot
                epoch
                pparams
                context
                inputs
                referenceInputs
                tx
        missingContext =
            baseMissingContext
        status =
            validationStatus contextErrors missingContext ledgerApplyResult
        complete =
            null contextErrors
                && null missingContext
                && ledgerApplyWasEvaluated ledgerApplyResult
        validForSuppliedContext =
            case status of
                "valid" -> Aeson.Bool True
                "invalid" -> Aeson.Bool False
                _ -> Aeson.Null
        checks =
            validationChecks contextErrors missingContext ledgerApplyResult
        failures =
            ledgerApplyFailures ledgerApplyResult
        warnings = validationWarnings contextErrors missingContext
     in Aeson.object
            [ "status" .= status
            , "valid_for_supplied_context" .= validForSuppliedContext
            , "complete" .= complete
            , "tx_id" .= txIdHex (Core.txIdTx tx)
            , "body_hash" .= txIdHex (Core.txIdTxBody body)
            , "checks" .= checks
            , "failures" .= failures
            , "missing_context" .= missingContext
            , "resolved_inputs"
                .= zipWith
                    (validationResolvedTxInJson "input" "inputs" context)
                    [0 :: Int ..]
                    inputs
            , "resolved_reference_inputs"
                .= zipWith
                    (validationResolvedTxInJson "reference_input" "reference_inputs" context)
                    [0 :: Int ..]
                    referenceInputs
            , "context"
                .= validationContextSummaryJson
                    inputPolicy
                    context
                    inputs
                    referenceInputs
                    unresolvedInputs
                    unresolvedReferenceInputs
                    (networkText <$> network)
                    (word64Text <$> slot)
                    (word64Text <$> epoch)
                    complete
            , "warnings" .= warnings
            , "errors" .= contextErrors
            ]

validationStatus ::
    [Aeson.Value] ->
    [Aeson.Value] ->
    LedgerApplyResult ->
    T.Text
validationStatus contextErrors missingContext ledgerApplyResult
    | not (null contextErrors) = "rejected"
    | not (null missingContext) = "incomplete"
    | otherwise =
        case ledgerApplyResult of
            LedgerApplyAccepted -> "valid"
            LedgerApplyRejected _ -> "invalid"
            LedgerApplyNotEvaluated _ -> "incomplete"

validationChecks ::
    [Aeson.Value] ->
    [Aeson.Value] ->
    LedgerApplyResult ->
    [Aeson.Value]
validationChecks contextErrors missingContext ledgerApplyResult =
    [ validationCheckJson
        "context.explicit"
        "Explicit validation context"
        (if null contextErrors then "passed" else "failed")
        "context"
        []
        ["args", "context"]
        ( if null contextErrors
            then "Supplied context is syntactically usable."
            else "Supplied context is malformed or contradictory."
        )
    , validationCheckJson
        "ledger.apply_tx"
        "Conway ledger validation"
        ledgerStatus
        "ledger"
        requiredLedgerContextKinds
        ["args", "context"]
        ledgerMessage
    ]
  where
    ledgerStatus
        | not (null contextErrors) = "not_evaluated"
        | not (null missingContext) = "not_evaluated"
        | otherwise =
            case ledgerApplyResult of
                LedgerApplyAccepted -> "passed"
                LedgerApplyRejected _ -> "failed"
                LedgerApplyNotEvaluated _ -> "not_evaluated"
    ledgerMessage
        | not (null contextErrors) =
            "Ledger validation was not run because the supplied context is invalid."
        | not (null missingContext) =
            "Ledger validation needs more explicit context before Conway applyTx can run."
        | otherwise =
            case ledgerApplyResult of
                LedgerApplyAccepted ->
                    "Conway applyTx accepted the transaction for the supplied context."
                LedgerApplyRejected _ ->
                    "Conway applyTx rejected the transaction for the supplied context."
                LedgerApplyNotEvaluated reason -> reason

requiredLedgerContextKinds :: [T.Text]
requiredLedgerContextKinds =
    [ "source_output"
    , "protocol_parameters"
    , "slot"
    , "epoch"
    , "network"
    ]

validationCheckJson ::
    T.Text ->
    T.Text ->
    T.Text ->
    T.Text ->
    [T.Text] ->
    [T.Text] ->
    T.Text ->
    Aeson.Value
validationCheckJson checkId title status scope requiredContext path message =
    Aeson.object
        [ "id" .= checkId
        , "title" .= title
        , "status" .= status
        , "scope" .= scope
        , "required_context" .= requiredContext
        , "path" .= path
        , "message" .= message
        ]

runLedgerApplyTx ::
    [Aeson.Value] ->
    [Aeson.Value] ->
    Maybe BaseTypes.Network ->
    Maybe Word64 ->
    Maybe Word64 ->
    Maybe (Core.PParams Conway.ConwayEra) ->
    ProducerContext ->
    [TxIn.TxIn] ->
    [TxIn.TxIn] ->
    L.Tx TopTx Conway.ConwayEra ->
    LedgerApplyResult
runLedgerApplyTx contextErrors missingContext network slot epoch pparams context inputs referenceInputs tx
    | not (null contextErrors) =
        LedgerApplyNotEvaluated
            "Conway applyTx was not run because validation context is invalid."
    | not (null missingContext) =
        LedgerApplyNotEvaluated
            "Conway applyTx was not run because validation context is incomplete."
    | otherwise =
        case (network, slot, epoch, pparams) of
            (Just network', Just slot', Just epoch', Just pparams') ->
                let globals = validationGlobals network'
                    newEpochState =
                        validationNewEpochState epoch' pparams' $
                            validationSourceUTxO context (inputs <> referenceInputs)
                    env =
                        Mempool.mkMempoolEnv
                            newEpochState
                            (BaseTypes.SlotNo slot')
                    state = Mempool.mkMempoolState newEpochState
                 in case Mempool.applyTx globals env state tx of
                        Right _ -> LedgerApplyAccepted
                        Left err -> LedgerApplyRejected (ledgerApplyErrorJson err)
            _ ->
                LedgerApplyNotEvaluated
                    "Conway applyTx was not run because required context parsing did not produce ledger values."

ledgerApplyWasEvaluated :: LedgerApplyResult -> Bool
ledgerApplyWasEvaluated LedgerApplyAccepted = True
ledgerApplyWasEvaluated (LedgerApplyRejected _) = True
ledgerApplyWasEvaluated (LedgerApplyNotEvaluated _) = False

ledgerApplyFailures :: LedgerApplyResult -> [Aeson.Value]
ledgerApplyFailures (LedgerApplyRejected failures) = failures
ledgerApplyFailures LedgerApplyAccepted = []
ledgerApplyFailures (LedgerApplyNotEvaluated _) = []

validationGlobals :: BaseTypes.Network -> BaseTypes.Globals
validationGlobals network =
    BaseTypes.Globals
        { BaseTypes.epochInfo =
            EpochInfo.fixedEpochInfo
                (BaseTypes.EpochSize 432000)
                (SlottingTime.mkSlotLength 1)
        , BaseTypes.slotsPerKESPeriod = 129600
        , BaseTypes.stabilityWindow = 129600
        , BaseTypes.randomnessStabilisationWindow = 172800
        , BaseTypes.securityParameter = BaseTypes.knownNonZeroBounded @2160
        , BaseTypes.maxKESEvo = 62
        , BaseTypes.quorum = 5
        , BaseTypes.maxLovelaceSupply = 45 * 1000 * 1000 * 1000 * 1000 * 1000
        , BaseTypes.activeSlotCoeff = defaultActiveSlotCoeff
        , BaseTypes.networkId = network
        , BaseTypes.systemStart =
            SlottingTime.SystemStart (posixSecondsToUTCTime 0)
        }

defaultActiveSlotCoeff :: BaseTypes.ActiveSlotCoeff
defaultActiveSlotCoeff =
    BaseTypes.mkActiveSlotCoeff $
        fromMaybe maxBound (BaseTypes.boundRational (1 % 20))

validationNewEpochState ::
    Word64 ->
    Core.PParams Conway.ConwayEra ->
    ShelleyState.UTxO Conway.ConwayEra ->
    ShelleyState.NewEpochState Conway.ConwayEra
validationNewEpochState epoch pparams utxo =
    (def :: ShelleyState.NewEpochState Conway.ConwayEra)
        & ShelleyState.nesELL .~ BaseTypes.EpochNo epoch
        & ShelleyState.nesEsL . ShelleyState.curPParamsEpochStateL .~ pparams
        & ShelleyState.nesEsL
            . ShelleyState.esLStateL
            . ShelleyState.lsUTxOStateL
            . ShelleyState.utxoL
            .~ utxo

validationSourceUTxO ::
    ProducerContext ->
    [TxIn.TxIn] ->
    ShelleyState.UTxO Conway.ConwayEra
validationSourceUTxO context txIns =
    ShelleyState.UTxO $
        Map.fromList
            [ (txIn, txOut)
            | txIn <- txIns
            , Just txOut <- [producerTxOutput context txIn]
            ]

ledgerApplyErrorJson :: Conway.ApplyTxError Conway.ConwayEra -> [Aeson.Value]
ledgerApplyErrorJson (Conway.ConwayApplyTxError failures) =
    zipWith ledgerFailureJson [0 :: Int ..] (toList failures)

ledgerFailureJson :: Int -> ConwayRules.ConwayLedgerPredFailure Conway.ConwayEra -> Aeson.Value
ledgerFailureJson ix failure =
    Aeson.object
        [ "kind" .= ("ledger_failure" :: T.Text)
        , "rule" .= ledgerFailureRule failure
        , "index" .= ix
        , "message" .= ledgerFailureMessage failure
        , "predicate" .= T.pack (show failure)
        , "path" .= (["body"] :: [T.Text])
        ]

ledgerFailureRule :: ConwayRules.ConwayLedgerPredFailure Conway.ConwayEra -> T.Text
ledgerFailureRule = \case
    ConwayRules.ConwayUtxowFailure _ -> "UTXOW"
    ConwayRules.ConwayCertsFailure _ -> "CERTS"
    ConwayRules.ConwayGovFailure _ -> "GOV"
    ConwayRules.ConwayWdrlNotDelegatedToDRep _ -> "LEDGER.withdrawals"
    ConwayRules.ConwayTreasuryValueMismatch _ -> "LEDGER.treasury"
    ConwayRules.ConwayTxRefScriptsSizeTooBig _ -> "LEDGER.reference_scripts"
    ConwayRules.ConwayMempoolFailure _ -> "MEMPOOL"
    ConwayRules.ConwayWithdrawalsMissingAccounts _ -> "LEDGER.withdrawals"
    ConwayRules.ConwayIncompleteWithdrawals _ -> "LEDGER.withdrawals"

ledgerFailureMessage :: ConwayRules.ConwayLedgerPredFailure Conway.ConwayEra -> T.Text
ledgerFailureMessage = \case
    ConwayRules.ConwayUtxowFailure failure ->
        "Transaction witness or UTxO validation failed: " <> T.pack (show failure)
    ConwayRules.ConwayCertsFailure failure ->
        "Certificate validation failed: " <> T.pack (show failure)
    ConwayRules.ConwayGovFailure failure ->
        "Governance validation failed: " <> T.pack (show failure)
    ConwayRules.ConwayWdrlNotDelegatedToDRep hashes ->
        "Withdrawal credentials are not delegated to a DRep: " <> T.pack (show hashes)
    ConwayRules.ConwayTreasuryValueMismatch mismatch ->
        "Treasury value does not match the ledger rule expectation: " <> T.pack (show mismatch)
    ConwayRules.ConwayTxRefScriptsSizeTooBig mismatch ->
        "Referenced scripts exceed the maximum allowed size: " <> T.pack (show mismatch)
    ConwayRules.ConwayMempoolFailure message ->
        message
    ConwayRules.ConwayWithdrawalsMissingAccounts withdrawals ->
        "Withdrawals reference missing reward accounts: " <> T.pack (show withdrawals)
    ConwayRules.ConwayIncompleteWithdrawals withdrawals ->
        "Withdrawals are incomplete for the supplied accounts: " <> T.pack (show withdrawals)

validationWarnings :: [Aeson.Value] -> [Aeson.Value] -> [T.Text]
validationWarnings contextErrors missingContext
    | null contextErrors && null missingContext =
        ["tx.validate did not mutate or return transaction CBOR."]
    | otherwise = []

requiredContextField ::
    T.Text ->
    T.Text ->
    T.Text ->
    (Aeson.Value -> Either T.Text a) ->
    Maybe Aeson.Value ->
    (Maybe a, [Aeson.Value], [Aeson.Value])
requiredContextField field kind message parse maybeContext =
    case maybeContext >>= lookupValue (AesonKey.fromText field) of
        Nothing ->
            ( Nothing
            ,
                [ missingContextJson
                    kind
                    message
                    ["args", "context", field]
                    ["ledger.apply_tx"]
                ]
            , []
            )
        Just value ->
            case parse value of
                Right parsed -> (Just parsed, [], [])
                Left err ->
                    ( Nothing
                    , []
                    ,
                        [ contextErrorJson
                            ("invalid_" <> kind)
                            (message <> " " <> err)
                            ["args", "context", field]
                            (Aeson.object ["detail" .= err])
                        ]
                    )

parseNetworkValue :: Aeson.Value -> Either T.Text BaseTypes.Network
parseNetworkValue (Aeson.String value) =
    case T.toLower value of
        "mainnet" -> Right BaseTypes.Mainnet
        "testnet" -> Right BaseTypes.Testnet
        _ -> Left "Expected \"mainnet\" or \"testnet\"."
parseNetworkValue _ =
    Left "Expected a string value."

networkText :: BaseTypes.Network -> T.Text
networkText BaseTypes.Mainnet = "mainnet"
networkText BaseTypes.Testnet = "testnet"

parseWord64Value :: T.Text -> Aeson.Value -> Either T.Text Word64
parseWord64Value _field value@(Aeson.Number _) =
    case Aeson.fromJSON value of
        Aeson.Success n -> Right n
        Aeson.Error err -> Left (T.pack err)
parseWord64Value field (Aeson.String value) =
    case readMaybe (T.unpack value) of
        Just n -> Right n
        Nothing -> Left ("Expected " <> field <> " as an unsigned integer string.")
parseWord64Value field _ =
    Left ("Expected " <> field <> " as an unsigned integer.")

word64Text :: Word64 -> T.Text
word64Text =
    T.pack . show

parseProtocolParametersValue ::
    Aeson.Value ->
    Either T.Text (Core.PParams Conway.ConwayEra)
parseProtocolParametersValue value =
    case Aeson.fromJSON value of
        Aeson.Success pparams -> Right pparams
        Aeson.Error err -> Left (T.pack err)

inputPolicyErrors :: T.Text -> [Aeson.Value]
inputPolicyErrors "preserve" = []
inputPolicyErrors policy =
    [ contextErrorJson
        "unsupported_input_policy"
        "tx.validate only supports input_policy = \"preserve\"."
        ["args", "input_policy"]
        (Aeson.object ["input_policy" .= policy])
    ]

unsupportedUtxoJsonErrors :: Maybe Aeson.Value -> [Aeson.Value]
unsupportedUtxoJsonErrors maybeContext =
    case maybeContext >>= lookupValue "utxo" of
        Nothing -> []
        Just _ ->
            [ contextErrorJson
                "unsupported_utxo_json"
                "Provider-specific UTxO JSON is not ledger evidence; supply producer transaction CBOR in context.producer_txs."
                ["args", "context", "utxo"]
                (Aeson.object [])
            ]

producerDecodeContextErrors :: ProducerContext -> [Aeson.Value]
producerDecodeContextErrors context =
    [ contextErrorJson
        "producer_tx_decode_failed"
        ("Producer transaction " <> txId <> " could not be decoded: " <> err)
        ["args", "context", "producer_txs", txId]
        (Aeson.object ["tx_id" .= txId])
    | (txId, producerTx) <- Map.toList (pcProducerTxs context)
    , Left err <- [ptDecoded producerTx]
    ]

producerTxIdContextErrors :: ProducerContext -> [Aeson.Value]
producerTxIdContextErrors context =
    [ contextErrorJson
        "producer_tx_id_mismatch"
        "Producer transaction map key does not match the decoded producer transaction id."
        ["args", "context", "producer_txs", declaredTxId]
        ( Aeson.object
            [ "declared_tx_id" .= declaredTxId
            , "actual_tx_id" .= actualTxId
            ]
        )
    | (declaredTxId, producerTx) <- Map.toList (pcProducerTxs context)
    , Right producer <- [ptDecoded producerTx]
    , let actualTxId = txIdHex (Core.txIdTx producer)
    , declaredTxId /= actualTxId
    ]

producerOutputIndexContextErrors ::
    T.Text ->
    T.Text ->
    ProducerContext ->
    [TxIn.TxIn] ->
    [Aeson.Value]
producerOutputIndexContextErrors inputKind collection context txIns =
    [ contextErrorJson
        "producer_output_index_missing"
        "Producer transaction CBOR was supplied but the referenced output index does not exist."
        ["body", collection, "#" <> T.pack (show ix)]
        ( Aeson.object
            [ "input_kind" .= inputKind
            , "tx_id" .= txInTxIdHex txIn
            , "index" .= txInIndex txIn
            , "source" .= ptSource producerTx
            ]
        )
    | (ix, txIn) <- zip [0 :: Int ..] txIns
    , Just producerTx <- [producerTxLookup context txIn]
    , Right producer <- [ptDecoded producerTx]
    , isNothing (producerOutputAt txIn producer)
    ]

unsupportedFeatureMissingContext ::
    Core.TxBody TopTx Conway.ConwayEra ->
    [Aeson.Value]
unsupportedFeatureMissingContext body =
    let certCount = length (toList (body ^. L.certsTxBodyL))
        withdrawalCount = withdrawalsCount (body ^. L.withdrawalsTxBodyL)
     in concat
            [ if certCount == 0
                then []
                else
                    [ missingContextJson
                        "cert_state"
                        "Supply certificate state for transactions containing certificates."
                        ["args", "context", "cert_state"]
                        ["ledger.apply_tx"]
                    ]
            , if withdrawalCount == 0
                then []
                else
                    [ missingContextJson
                        "cert_state"
                        "Supply certificate/account state for transactions containing withdrawals."
                        ["args", "context", "cert_state"]
                        ["ledger.apply_tx"]
                    ]
            ]

missingSourceOutputContextJson ::
    T.Text ->
    T.Text ->
    Int ->
    TxIn.TxIn ->
    Aeson.Value
missingSourceOutputContextJson inputKind collection ix txIn =
    Aeson.object
        [ "kind" .= ("source_output" :: T.Text)
        , "message"
            .= ( "Supply producer transaction CBOR for the referenced transaction input." ::
                    T.Text
               )
        , "path" .= (["body", collection, "#" <> T.pack (show ix)] :: [T.Text])
        , "tx_id" .= txInTxIdHex txIn
        , "index" .= txInIndex txIn
        , "input_kind" .= inputKind
        , "required_for" .= (["ledger.apply_tx"] :: [T.Text])
        ]

missingContextJson ::
    T.Text ->
    T.Text ->
    [T.Text] ->
    [T.Text] ->
    Aeson.Value
missingContextJson kind message path requiredFor =
    Aeson.object
        [ "kind" .= kind
        , "message" .= message
        , "path" .= path
        , "required_for" .= requiredFor
        ]

contextErrorJson ::
    T.Text ->
    T.Text ->
    [T.Text] ->
    Aeson.Value ->
    Aeson.Value
contextErrorJson code message path details =
    Aeson.object
        [ "code" .= code
        , "message" .= message
        , "path" .= path
        , "details" .= details
        ]

validationResolvedTxInJson ::
    T.Text ->
    T.Text ->
    ProducerContext ->
    Int ->
    TxIn.TxIn ->
    Aeson.Value
validationResolvedTxInJson inputKind collection context ix txIn =
    let key = txInKey txIn
        baseFields =
            [ "key" .= key
            , "tx_id" .= txInTxIdHex txIn
            , "index" .= txInIndex txIn
            , "kind" .= inputKind
            , "path" .= (["body", collection, "#" <> T.pack (show ix)] :: [T.Text])
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

validationContextSummaryJson ::
    T.Text ->
    ProducerContext ->
    [TxIn.TxIn] ->
    [TxIn.TxIn] ->
    [TxIn.TxIn] ->
    [TxIn.TxIn] ->
    Maybe T.Text ->
    Maybe T.Text ->
    Maybe T.Text ->
    Bool ->
    Aeson.Value
validationContextSummaryJson
    inputPolicy
    context
    inputs
    referenceInputs
    missingInputs
    missingReferenceInputs
    network
    slot
    epoch
    complete =
        let resolvedInputs =
                length inputs - length missingInputs
            resolvedReferenceInputs =
                length referenceInputs - length missingReferenceInputs
            optionalFields =
                maybeTextField "network" network
                    <> maybeTextField "slot" slot
                    <> maybeTextField "epoch" epoch
         in Aeson.object $
                [ "input_policy" .= inputPolicy
                , "producer_tx_count" .= Map.size (pcProducerTxs context)
                , "decoded_producer_tx_count" .= decodedProducerTxCount context
                , "producer_tx_errors" .= producerTxErrors context
                , "supplied" .= producerContextSupplied context
                , "complete" .= complete
                , "input_count" .= length inputs
                , "resolved_input_count" .= resolvedInputs
                , "missing_input_count" .= length missingInputs
                , "reference_input_count" .= length referenceInputs
                , "resolved_reference_input_count" .= resolvedReferenceInputs
                , "missing_reference_input_count" .= length missingReferenceInputs
                , "unspent_status" .= ("not_checked" :: T.Text)
                , "resolution" .= fromMaybe Aeson.Null (ucResolution context)
                ]
                    <> optionalFields

maybeTextField :: AesonKey.Key -> Maybe T.Text -> [(AesonKey.Key, Aeson.Value)]
maybeTextField key =
    maybe [] (\value -> [key .= value])
