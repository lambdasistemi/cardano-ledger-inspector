{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Applicative ((<|>))
import qualified Data.Aeson as Aeson
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, isJust)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TIO
import Network.HTTP.Client (Manager)
import Network.HTTP.Client.TLS (newTlsManager)
import Options.Applicative
import qualified Paths_tx_deep_diagnosis as Paths
import System.Environment (lookupEnv)
import System.Exit (die)
import System.IO (hPutStrLn, stderr)

import TxDeepDiagnosisHost.Blockfrost
import TxDeepDiagnosisHost.Diagnosis
import TxDeepDiagnosisHost.Registry (loadRegistries)
import TxDeepDiagnosisHost.Render.Doc (parseDiagnosisDoc)
import TxDeepDiagnosisHost.Render.Emit (emitExplain)
import TxDeepDiagnosisHost.Render.Single (renderSingleMarkdown)
import TxDeepDiagnosisHost.Report (buildReportValue, renderReport)

data OutputFormat
    = OutputJson
    | OutputExplain
    deriving (Eq, Show)

data Options = Options
    { optCborFile :: !FilePath
    , optExtraRegistries :: ![FilePath]
    , optNoBundledRegistry :: !Bool
    , optOutputFormat :: !OutputFormat
    , optEmitExplain :: !(Maybe FilePath)
    , optNetwork :: !Network
    , optProjectId :: !(Maybe String)
    }

parseOpts :: Parser Options
parseOpts =
    Options
        <$> strOption
            ( long "cbor"
                <> metavar "FILE"
                <> help "Path to a file containing the Conway tx CBOR hex"
            )
        <*> many
            ( strOption
                ( long "registry"
                    <> metavar "DIR"
                    <> help
                        ( "Extra protocol registry directory to layer on top of "
                            <> "the bundled one. Repeat to add several. Validator + "
                            <> "instance entries from extra roots concat onto the "
                            <> "bundled list; the Amaru journal is last-wins."
                        )
                )
            )
        <*> switch
            ( long "no-bundled-registry"
                <> help
                    ( "Skip the registry vendored into this binary at build "
                        <> "time. Only the directories passed via --registry are "
                        <> "consulted. Rare; meant for testing a clean replacement."
                    )
            )
        <*> option
            parseOutputFormat
            ( long "format"
                <> metavar "FORMAT"
                <> value OutputJson
                <> help "stdout format: json | explain"
            )
        <*> optional
            ( strOption
                ( long "emit-explain"
                    <> metavar "DIR"
                    <> help
                        ( "Also write summary.md, explain.md, and diagram "
                            <> "artifacts to DIR."
                        )
                )
            )
        <*> option
            parseNet
            ( long "network"
                <> metavar "NETWORK"
                <> value Mainnet
                <> help "mainnet | preprod | preview"
            )
        <*> optional
            ( strOption
                ( long "blockfrost-id"
                    <> metavar "PROJECT_ID"
                    <> help "Blockfrost project_id (or BLOCKFROST_PROJECT_ID env var)"
                )
            )
  where
    parseNet = eitherReader $ \s -> case s of
        "mainnet" -> Right Mainnet
        "preprod" -> Right Preprod
        "preview" -> Right Preview
        _ -> Left ("unknown network: " <> s)
    parseOutputFormat = eitherReader $ \s -> case s of
        "json" -> Right OutputJson
        "explain" -> Right OutputExplain
        _ ->
            Left
                ("unknown format: " <> s <> " (expected json or explain)")

main :: IO ()
main = do
    opts <-
        execParser
            ( info
                (parseOpts <**> helper)
                ( progDesc
                    "Layered Conway tx diagnosis using cardano-ledger-conway via cardano-ledger-inspector library"
                )
            )
    pidFromEnv <- lookupEnv "BLOCKFROST_PROJECT_ID"
    let mpid = fmap Text.pack (optProjectId opts) <|> fmap Text.pack pidFromEnv
    hex <- Text.strip <$> TIO.readFile (optCborFile opts)
    bundledRegistry <- Paths.getDataDir
    let registryRoots =
            [bundledRegistry | not (optNoBundledRegistry opts)]
                <> optExtraRegistries opts
    reg <- loadRegistries registryRoots
    intent <- case runIntent hex of
        Left e -> die ("intent error: " <> e)
        Right v -> pure v
    mgr <- newTlsManager
    -- Phase 1: probe validate with no context to discover what producer
    -- txs + which validation-context fields the validator needs.
    probe <- case runValidate hex emptyContext of
        Left e -> die ("validate probe error: " <> e)
        Right v -> pure v
    let producerHashes = extractProducerTxIds probe
    -- Phase 2: fetch producer CBORs + latest block + protocol params.
    (producerCbors, mLatest, mPParams) <- case mpid of
        Nothing -> do
            hPutStrLn
                stderr
                "WARNING: no Blockfrost project_id; tx.validate will run with empty context (only the probe response is shown)."
            pure (Map.empty, Nothing, Nothing)
        Just pid -> do
            entries <-
                mapM (fetchProducer mgr (optNetwork opts) pid) producerHashes
            let prods =
                    Map.fromList
                        [(h, c) | (h, Right c) <- entries]
            mLb <- fetchLatestBlock mgr (optNetwork opts) pid
            mPp <- fetchProtocolParametersJson mgr (optNetwork opts) pid
            case (mLb, mPp) of
                (Right lb, Right pp) ->
                    pure (prods, Just lb, Just (remapPParamsToLedger pp))
                (lbErr, ppErr) -> do
                    case lbErr of
                        Left e -> hPutStrLn stderr ("blocks/latest fetch failed: " <> e)
                        _ -> pure ()
                    case ppErr of
                        Left e -> hPutStrLn stderr ("protocol-parameters fetch failed: " <> e)
                        _ -> pure ()
                    pure (prods, Nothing, Nothing)
    -- Phase 2.5: build cert_state by fetching the rewards balance for
    -- every withdrawal credential the probe surfaced.
    let withdrawalCreds = extractMissingWithdrawalCredentials probe
    mCertState <- case mpid of
        Just pid
            | not (null withdrawalCreds) ->
                Just <$> buildCertState mgr (optNetwork opts) pid withdrawalCreds
        _ -> pure Nothing
    -- Phase 3: validate again with everything we collected.
    let fullCtx =
            ValidationContext
                { vcProducerTxs = producerCbors
                , vcNetwork = Just (networkLedgerName (optNetwork opts))
                , vcSlot = fmap lbSlot mLatest
                , vcEpoch = fmap lbEpoch mLatest
                , vcProtocolParameters = mPParams
                , vcCertState = mCertState
                }
    validate <- case runValidate hex fullCtx of
        Left e -> die ("validate error: " <> e)
        Right v -> pure v
    let reportSummary =
            Text.pack (show (Map.size producerCbors))
                <> "/"
                <> Text.pack (show (length producerHashes))
                <> " producer txs resolved, network="
                <> networkLedgerName (optNetwork opts)
        reportValue = buildReportValue reportSummary intent validate
        needsExplainDoc =
            optOutputFormat opts == OutputExplain
                || isJust (optEmitExplain opts)
    mDoc <-
        if needsExplainDoc
            then case parseDiagnosisDoc reportValue of
                Left e -> die ("internal explain parse error: " <> e)
                Right doc -> pure (Just doc)
            else pure Nothing
    case (optOutputFormat opts, mDoc) of
        (OutputJson, _) ->
            TIO.putStr (renderReport reportSummary intent validate reg)
        (OutputExplain, Just doc) ->
            TIO.putStr (renderSingleMarkdown reg doc)
        (OutputExplain, Nothing) ->
            die "internal explain parse error: missing explain document"
    case (optEmitExplain opts, mDoc) of
        (Nothing, _) -> pure ()
        (Just outDir, Just doc) -> do
            _ <- emitExplain outDir reg doc
            pure ()
        (Just _, Nothing) ->
            die "internal explain emit error: missing explain document"

fetchProducer
    :: Manager -> Network -> Text -> Text -> IO (Text, Either String Text)
fetchProducer mgr net pid h = do
    eCbor <- fetchTxCbor mgr net pid h
    case eCbor of
        Right c -> pure (h, Right c)
        Left e -> do
            hPutStrLn
                stderr
                ("producer fetch failed for " <> Text.unpack h <> ": " <> e)
            pure (h, Left e)

{- | For each withdrawal credential surfaced by the probe, look up the
 current rewards balance via Blockfrost and assemble the cert_state
 JSON the inspector library expects. Failures (bad bech32 derivation,
 HTTP errors, unregistered accounts) are logged but do not abort —
 the unresolved credentials simply do not appear in the output, and
 the ledger will then surface its own CERTS error for them, which is
 more useful diagnostic output than a host-side abort.
-}
buildCertState
    :: Manager -> Network -> Text -> [WithdrawalCredential] -> IO Aeson.Value
buildCertState mgr net pid creds = do
    rewardEntries <- mapM (fetchRewardsEntry mgr net pid) creds
    pure $
        Aeson.object
            [ ("rewards", Aeson.toJSON (catMaybes rewardEntries))
            ]

fetchRewardsEntry
    :: Manager
    -> Network
    -> Text
    -> WithdrawalCredential
    -> IO (Maybe Aeson.Value)
fetchRewardsEntry mgr net pid cred = do
    let kind = case wcKind cred of
            "script" -> Just ScriptCred
            "key" -> Just KeyCred
            _ -> Nothing
    case kind of
        Nothing -> do
            hPutStrLn
                stderr
                ("unknown credential.kind: " <> Text.unpack (wcKind cred))
            pure Nothing
        Just k -> case stakeAddressBech32 net k (wcHash cred) of
            Left e -> do
                hPutStrLn
                    stderr
                    ( "stake-address derivation failed for "
                        <> Text.unpack (wcHash cred)
                        <> ": "
                        <> e
                    )
                pure Nothing
            Right stake -> do
                eAcc <- fetchAccountInfo mgr net pid stake
                case eAcc of
                    Left e -> do
                        hPutStrLn
                            stderr
                            ( "account fetch failed for "
                                <> Text.unpack stake
                                <> ": "
                                <> e
                            )
                        pure Nothing
                    Right info
                        | not (aiRegistered info) -> do
                            -- Truly unknown to the chain. Skip; CERTS
                            -- will then reject with a clear message
                            -- naming the credential, which is the right
                            -- diagnostic signal for the user.
                            hPutStrLn
                                stderr
                                ( "stake credential never registered on chain: "
                                    <> Text.unpack stake
                                    <> " (CERTS will reject this withdrawal)"
                                )
                            pure Nothing
                        | otherwise -> do
                            -- registered=true with active=false is the
                            -- normal state for a withdraw-zero trigger
                            -- script that never delegates ADA — seed
                            -- and let the ledger evaluate.
                            pure $
                                Just $
                                    Aeson.object
                                        [ ("credential", credentialJson cred)
                                        ,
                                            ( "balance_lovelace"
                                            , Aeson.String (Text.pack (show (aiWithdrawableLovelace info)))
                                            )
                                        ]

credentialJson :: WithdrawalCredential -> Aeson.Value
credentialJson cred =
    Aeson.object
        [ ("kind", Aeson.String (wcKind cred))
        , ("hash", Aeson.String (wcHash cred))
        ]
