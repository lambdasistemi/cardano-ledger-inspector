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
import TxDeepDiagnosisHost.Render.Failures (renderFailuresMermaid)
import TxDeepDiagnosisHost.Render.Parties (renderPartiesMermaid)
import TxDeepDiagnosisHost.Render.Single (renderSingleMarkdown)
import TxDeepDiagnosisHost.Render.Summary (
    EmittedFiles (..),
    renderSummaryMarkdown,
 )
import TxDeepDiagnosisHost.Render.Topology (renderTopologyMermaid)
import TxDeepDiagnosisHost.Render.ValueFlow (renderValueFlowTsv)

{- | All artifacts the harness can produce, in emit order. Failures
and summary are conditional on doc state and produce 'Maybe'
output.
-}
data Artifact
    = Always !FilePath !(ProtocolRegistry -> DiagnosisDoc -> Text)
    | Conditional !FilePath !(ProtocolRegistry -> DiagnosisDoc -> Maybe Text)
    | -- | Summary depends on which other files were emitted, so it
      -- runs last and receives the cumulative 'EmittedFiles'.
      SummaryArtifact !FilePath

renderers :: [Artifact]
renderers =
    [ Always "parties.mmd" renderPartiesMermaid
    , Always "value-flow.tsv" renderValueFlowTsv
    , Always "topology.mmd" renderTopologyMermaid
    , Conditional "failures.mmd" renderFailuresMermaid
    , SummaryArtifact "summary.md"
    , Always "explain.md" renderSingleMarkdown
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
                let initial = noEmittedFilesLocal
                (outcomes, _emitted) <-
                    foldArtifacts mode reg root name doc initial renderers
                pure (name, and outcomes)

noEmittedFilesLocal :: EmittedFiles
noEmittedFilesLocal =
    EmittedFiles
        { efParties = Nothing
        , efValueFlow = Nothing
        , efTopology = Nothing
        , efFailures = Nothing
        }

{- | Apply each artifact in order, threading 'EmittedFiles' so the
summary can link only to files that were actually written.
-}
foldArtifacts ::
    Mode ->
    ProtocolRegistry ->
    FilePath ->
    FilePath ->
    DiagnosisDoc ->
    EmittedFiles ->
    [Artifact] ->
    IO ([Bool], EmittedFiles)
foldArtifacts _ _ _ _ _ acc [] = pure ([], acc)
foldArtifacts mode reg root name doc acc (a : as) = do
    (ok, acc') <- handleArtifact mode reg root name doc acc a
    (rest, accFinal) <- foldArtifacts mode reg root name doc acc' as
    pure (ok : rest, accFinal)

handleArtifact ::
    Mode ->
    ProtocolRegistry ->
    FilePath ->
    FilePath ->
    DiagnosisDoc ->
    EmittedFiles ->
    Artifact ->
    IO (Bool, EmittedFiles)
handleArtifact mode reg root name doc files art = case art of
    Always file render -> do
        let actual = render reg doc
        ok <- handle mode reg root name file actual
        pure (ok, recordFile file files)
    Conditional file render -> case render reg doc of
        Nothing ->
            -- Skipped on purpose; tolerate any leftover expected file.
            pure (True, files)
        Just actual -> do
            ok <- handle mode reg root name file actual
            pure (ok, recordFile file files)
    SummaryArtifact file -> do
        let actual = renderSummaryMarkdown reg doc files
        ok <- handle mode reg root name file actual
        pure (ok, recordFile file files)

recordFile :: FilePath -> EmittedFiles -> EmittedFiles
recordFile "parties.mmd" f = f{efParties = Just "parties.mmd"}
recordFile "value-flow.tsv" f = f{efValueFlow = Just "value-flow.tsv"}
recordFile "topology.mmd" f = f{efTopology = Just "topology.mmd"}
recordFile "failures.mmd" f = f{efFailures = Just "failures.mmd"}
recordFile _ f = f

handle ::
    Mode ->
    ProtocolRegistry ->
    FilePath ->
    FilePath ->
    FilePath ->
    Text ->
    IO Bool
handle WriteMode _reg root name file actual = do
    let expectedDir = root </> name </> "expected"
        expectedPath = expectedDir </> file
    exists <- doesDirectoryExist expectedDir
    unless exists $ die ("missing expected dir: " <> expectedDir)
    TIO.writeFile expectedPath actual
    putStrLn ("wrote " <> expectedPath)
    pure True
handle CompareMode _reg root name file actual = do
    let expectedPath = root </> name </> "expected" </> file
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
                            <> file
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
