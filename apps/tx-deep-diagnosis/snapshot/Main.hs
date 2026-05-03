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
import qualified Data.Text as Text
import qualified Data.Text.IO as TIO
import qualified Paths_tx_deep_diagnosis as Paths
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)
import System.FilePath ((</>))
import System.IO (hPutStrLn, stderr)

import TxDeepDiagnosisHost.Registry (loadRegistries)
import TxDeepDiagnosisHost.Render.Doc (parseDiagnosisDoc)

main :: IO ()
main = do
    args <- getArgs
    goldenRoot <- case args of
        [p] -> pure p
        _ ->
            die
                "usage: tx-deep-diagnosis-render-snapshot <golden-root>\n"
    bundled <- Paths.getDataDir
    _reg <- loadRegistries [bundled]
    cases <- listGoldenCases goldenRoot
    when (null cases) $
        die ("no golden cases found under " <> goldenRoot)
    results <- forM cases (runCase _reg goldenRoot)
    let failed = [name | (name, False) <- results]
    if null failed
        then do
            mapM_ (\(name, _) -> putStrLn ("ok   " <> name)) results
            exitSuccess
        else do
            mapM_
                ( \(name, ok) ->
                    putStrLn ((if ok then "ok   " else "FAIL ") <> name)
                )
                results
            exitFailure

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
match, @False@ otherwise. The renderer set is currently empty; each
renderer commit will extend 'renderers' to add a new (artifact name,
producer) entry.
-}
runCase ::
    -- | bundled protocol registry; passed for forward use as renderers land
    a ->
    -- | golden root
    FilePath ->
    -- | case name (subdir of root)
    FilePath ->
    IO (FilePath, Bool)
runCase _reg root name = do
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
            Right _doc -> do
                -- Renderer set is empty for now; the case passes if the
                -- envelope decodes. Subsequent commits extend this with
                -- per-artifact byte equality checks against
                -- expected/<file>.
                pure (name, True)

die :: String -> IO a
die msg = do
    hPutStrLn stderr msg
    exitFailure

-- Silence "defined but not used" until the renderer wiring lands.
_unused :: ()
_unused = const () (Text.pack "", TIO.hPutStrLn)
