{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Main
Description : Snapshot harness for the explain renderers.

Walks @apps/tx-deep-diagnosis/test/golden/<case>/@ trees, runs every
renderer the harness knows about against @input.json@, and compares
each emitted artifact byte-for-byte against @expected/<file>@.

Failure mode: print a unified-style diff for each mismatching file and
exit non-zero. Success mode: print one line per case and exit zero.

The harness is on purpose deliberately dumb — it does not invoke the
ledger and it does not call Blockfrost. Its only inputs are the JSON
envelope and the bundled 'ProtocolRegistry'.
-}
module Main (main) where

import Control.Monad (forM, unless, when)
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BSL
import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TIO
import qualified Paths_tx_deep_diagnosis as Paths
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)
import System.FilePath ((</>))
import System.IO (hPutStrLn, stderr)

import TxDeepDiagnosisHost.Registry (ProtocolRegistry, loadRegistries)
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc, parseDiagnosisDoc)
import TxDeepDiagnosisHost.Render.Parties (renderPartiesMermaid)
import TxDeepDiagnosisHost.Render.ValueFlow (renderValueFlowTsv)

{- | Static registry of (relative file name, producer) pairs. Each
renderer commit appends one line.
-}
renderers :: [(FilePath, ProtocolRegistry -> DiagnosisDoc -> Text)]
renderers =
    [ ("parties.mmd", renderPartiesMermaid)
    , ("value-flow.tsv", renderValueFlowTsv)
    ]

main :: IO ()
main = do
    args <- getArgs
    (mode, goldenRoot) <- case args of
        [p] -> pure (CompareMode, p)
        ["--write", p] -> pure (WriteMode, p)
        _ ->
            die
                ( "usage: tx-deep-diagnosis-render-snapshot [--write] "
                    <> "<golden-root>\n"
                )
    bundled <- Paths.getDataDir
    reg <- loadRegistries [bundled]
    cases <- listGoldenCases goldenRoot
    when (null cases) $
        die ("no golden cases found under " <> goldenRoot)
    results <- forM cases (runCase mode reg goldenRoot)
    let failed = [name | (name, False) <- results]
    mapM_
        ( \(name, ok) ->
            putStrLn ((if ok then "ok   " else "FAIL ") <> name)
        )
        results
    if null failed then exitSuccess else exitFailure

listGoldenCases :: FilePath -> IO [FilePath]
listGoldenCases root = do
    exists <- doesDirectoryExist root
    if not exists
        then pure []
        else do
            entries <- listDirectory root
            sort
                <$> filterM
                    (\e -> doesDirectoryExist (root </> e))
                    entries

filterM :: (a -> IO Bool) -> [a] -> IO [a]
filterM _ [] = pure []
filterM p (x : xs) = do
    keep <- p x
    rest <- filterM p xs
    pure (if keep then x : rest else rest)

{- | Run all renderers for a single golden case. Returns @True@ on
match, @False@ otherwise.
-}
data Mode = CompareMode | WriteMode
    deriving (Eq)

runCase :: Mode -> ProtocolRegistry -> FilePath -> FilePath -> IO (FilePath, Bool)
runCase mode reg root name = do
    let inputPath = root </> name </> "input.json"
    inputExists <- doesFileExist inputPath
    unless inputExists $
        die ("missing " <> inputPath)
    raw <- BSL.readFile inputPath
    case A.eitherDecode raw of
        Left e -> do
            hPutStrLn stderr ("decode " <> inputPath <> ": " <> e)
            pure (name, False)
        Right v -> case parseDiagnosisDoc v of
            Left e -> do
                hPutStrLn stderr ("parse " <> inputPath <> ": " <> e)
                pure (name, False)
            Right doc -> do
                outcomes <-
                    mapM
                        (handleArtifact mode reg root name doc)
                        renderers
                pure (name, and outcomes)

handleArtifact ::
    Mode ->
    ProtocolRegistry ->
    FilePath ->
    FilePath ->
    DiagnosisDoc ->
    (FilePath, ProtocolRegistry -> DiagnosisDoc -> Text) ->
    IO Bool
handleArtifact WriteMode reg root name doc (artifact, render) = do
    let expectedDir = root </> name </> "expected"
        expectedPath = expectedDir </> artifact
    exists <- doesDirectoryExist expectedDir
    unless exists $ die ("missing expected dir: " <> expectedDir)
    TIO.writeFile expectedPath (render reg doc)
    putStrLn ("wrote " <> expectedPath)
    pure True
handleArtifact CompareMode reg root name doc args =
    compareArtifact reg root name doc args

compareArtifact ::
    ProtocolRegistry ->
    FilePath ->
    FilePath ->
    DiagnosisDoc ->
    (FilePath, ProtocolRegistry -> DiagnosisDoc -> Text) ->
    IO Bool
compareArtifact reg root name doc (artifact, render) = do
    let expectedPath = root </> name </> "expected" </> artifact
        actual = render reg doc
    expectedExists <- doesFileExist expectedPath
    if not expectedExists
        then do
            hPutStrLn
                stderr
                ( "MISSING expected file: "
                    <> expectedPath
                    <> "\n--- actual output ---\n"
                    <> Text.unpack actual
                    <> "--- end ---"
                )
            pure False
        else do
            expected <- TIO.readFile expectedPath
            if expected == actual
                then pure True
                else do
                    hPutStrLn
                        stderr
                        ( "DIFF in "
                            <> name
                            <> "/"
                            <> artifact
                            <> ":\n--- expected ---\n"
                            <> Text.unpack expected
                            <> "--- actual ---\n"
                            <> Text.unpack actual
                            <> "--- end ---"
                        )
                    pure False

die :: String -> IO a
die msg = do
    hPutStrLn stderr msg
    exitFailure
