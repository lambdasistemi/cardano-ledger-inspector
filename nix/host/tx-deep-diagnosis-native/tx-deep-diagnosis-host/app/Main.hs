{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Applicative ((<|>))
import qualified Data.Aeson as Aeson
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TIO
import Network.HTTP.Client (Manager)
import Network.HTTP.Client.TLS (newTlsManager)
import Options.Applicative
import System.Environment (lookupEnv)
import System.Exit (die)
import System.IO (hPutStrLn, stderr)

import TxDeepDiagnosisHost.Blockfrost
import TxDeepDiagnosisHost.Diagnosis
import TxDeepDiagnosisHost.Registry (loadRegistry)
import TxDeepDiagnosisHost.Report (renderTopLevel)

data Options = Options
    { optCborFile :: !FilePath
    , optRegistryDir :: !FilePath
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
        <*> strOption
            ( long "registry"
                <> metavar "DIR"
                <> value "docs/inspector/protocols"
                <> help "Path to the protocol registry directory"
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

main :: IO ()
main = do
    opts <-
        execParser
            ( info
                (parseOpts <**> helper)
                (progDesc "Layered Conway tx diagnosis using cardano-ledger-conway via cardano-ledger-inspector library")
            )
    pidFromEnv <- lookupEnv "BLOCKFROST_PROJECT_ID"
    let mpid = fmap Text.pack (optProjectId opts) <|> fmap Text.pack pidFromEnv
    hex <- Text.strip <$> TIO.readFile (optCborFile opts)
    reg <- loadRegistry (optRegistryDir opts)
    intent <- case runIntent hex of
        Left e -> die ("intent error: " <> e)
        Right v -> pure v
    mgr <- newTlsManager
    let producerHashes = extractProducerHashes intent
    producerCbors <- case mpid of
        Nothing -> do
            hPutStrLn
                stderr
                "WARNING: no Blockfrost project_id; tx.validate will run with empty context."
            pure Map.empty
        Just pid -> do
            entries <- mapM (fetchProducer mgr (optNetwork opts) pid) producerHashes
            pure (Map.fromList [(h, c) | (h, Right c) <- entries])
    validate <- case runValidate hex producerCbors of
        Left e -> die ("validate error: " <> e)
        Right v -> pure v
    TIO.putStr
        ( renderTopLevel
            ( "tx-deep-diagnosis  ("
                <> Text.pack (show (Map.size producerCbors))
                <> " producer txs resolved)"
            )
            intent
            validate
            reg
        )

fetchProducer ::
    Manager -> Network -> Text -> Text -> IO (Text, Either String Text)
fetchProducer mgr net pid h = do
    eCbor <- fetchTxCbor mgr net pid h
    case eCbor of
        Right c -> pure (h, Right c)
        Left e -> do
            hPutStrLn
                stderr
                ("producer fetch failed for " <> Text.unpack h <> ": " <> e)
            pure (h, Left e)

extractProducerHashes :: Aeson.Value -> [Text]
extractProducerHashes _ = []
