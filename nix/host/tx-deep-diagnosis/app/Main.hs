{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import qualified Data.Text as Text
import qualified Data.Text.IO as TIO
import Network.HTTP.Client.TLS (newTlsManager)
import Options.Applicative
import System.Environment (lookupEnv)
import System.Exit (die)
import System.IO (hPutStrLn, stderr)

import TxDeepDiagnosis.Conway (decodeTxFromCborHex)
import TxDeepDiagnosis.Diagnosis (runDiagnosis)
import TxDeepDiagnosis.Registry (loadRegistry)
import TxDeepDiagnosis.Report (renderReport)
import TxDeepDiagnosis.Types (Network (..))

data Options = Options
    { optCborFile :: !FilePath
    , optRegistryDir :: !FilePath
    , optNetwork :: !Network
    , optProjectId :: !(Maybe String)
    }

parseOpts :: Parser Options
parseOpts = Options
    <$> strOption (long "cbor" <> metavar "FILE"
        <> help "Path to a file containing the Conway tx CBOR hex")
    <*> strOption (long "registry" <> metavar "DIR" <> value "docs/inspector/protocols"
        <> help "Path to the protocol registry directory (default: docs/inspector/protocols)")
    <*> option parseNet (long "network" <> metavar "mainnet|preprod|preview" <> value Mainnet
        <> help "Network for Blockfrost lookups (default: mainnet)")
    <*> optional (strOption (long "blockfrost-id" <> metavar "PROJECT_ID"
        <> help "Blockfrost project_id (or set BLOCKFROST_PROJECT_ID env var)"))
  where
    parseNet = eitherReader $ \s -> case s of
        "mainnet" -> Right Mainnet
        "preprod" -> Right Preprod
        "preview" -> Right Preview
        _ -> Left ("unknown network: " <> s)

main :: IO ()
main = do
    opts <- execParser (info (parseOpts <**> helper) (progDesc "Layered Conway tx diagnosis"))
    pidFromOpt <- pure (optProjectId opts)
    pidFromEnv <- lookupEnv "BLOCKFROST_PROJECT_ID"
    let mpid = fmap Text.pack (pidFromOpt <> pidFromEnv)
    hex <- TIO.readFile (optCborFile opts)
    tx <- case decodeTxFromCborHex hex of
        Left e -> die ("CBOR decode error: " <> e)
        Right tx -> pure tx
    reg <- loadRegistry (optRegistryDir opts)
    mgr <- newTlsManager
    case mpid of
        Nothing -> hPutStrLn stderr "WARNING: no Blockfrost project_id; layer 7 (input resolution) will be skipped."
        Just _ -> pure ()
    dg <- runDiagnosis mgr (optNetwork opts) mpid reg tx
    TIO.putStr (renderReport dg)
