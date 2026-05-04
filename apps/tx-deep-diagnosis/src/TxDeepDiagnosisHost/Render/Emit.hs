{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Emit
Description : Shared explain-artifact assembly and file emission.

Both the runtime CLI and the snapshot harness use this module so artifact
ordering, optional files, and summary footer links stay in sync.
-}
module TxDeepDiagnosisHost.Render.Emit
    ( renderExplainArtifacts
    , emitExplain
    ) where

import Control.Monad (forM_, when)
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text.IO as TIO
import System.Directory
    ( createDirectoryIfMissing
    , doesFileExist
    , removeFile
    )
import System.FilePath ((</>))

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc)
import TxDeepDiagnosisHost.Render.Failures (renderFailuresMermaid)
import TxDeepDiagnosisHost.Render.Parties (renderPartiesMermaid)
import TxDeepDiagnosisHost.Render.Single (renderSingleMarkdown)
import TxDeepDiagnosisHost.Render.Summary
    ( EmittedFiles (..)
    , renderSummaryMarkdown
    )
import TxDeepDiagnosisHost.Render.Topology (renderTopologyMermaid)
import TxDeepDiagnosisHost.Render.ValueFlow (renderValueFlowTsv)

renderExplainArtifacts
    :: ProtocolRegistry -> DiagnosisDoc -> [(FilePath, Text)]
renderExplainArtifacts reg doc =
    let failuresText = renderFailuresMermaid reg doc
        emittedFiles =
            EmittedFiles
                { efParties = Just partiesFile
                , efValueFlow = Just valueFlowFile
                , efTopology = Just topologyFile
                , efFailures =
                    if isJust failuresText then Just failuresFile else Nothing
                }
        artifacts =
            [ (partiesFile, renderPartiesMermaid reg doc)
            , (valueFlowFile, renderValueFlowTsv reg doc)
            , (topologyFile, renderTopologyMermaid reg doc)
            ]
                <> maybe [] (\body -> [(failuresFile, body)]) failuresText
                <> [ (summaryFile, renderSummaryMarkdown reg doc emittedFiles)
                   , (explainFile, renderSingleMarkdown reg doc)
                   ]
    in  artifacts
  where
    partiesFile = "parties.mmd"
    valueFlowFile = "value-flow.tsv"
    topologyFile = "topology.mmd"
    failuresFile = "failures.mmd"
    summaryFile = "summary.md"
    explainFile = "explain.md"

emitExplain
    :: FilePath -> ProtocolRegistry -> DiagnosisDoc -> IO [FilePath]
emitExplain outDir reg doc = do
    let artifacts = renderExplainArtifacts reg doc
        writtenNames = map fst artifacts
    createDirectoryIfMissing True outDir
    forM_ knownExplainArtifacts $ \name -> do
        let path = outDir </> name
        exists <- doesFileExist path
        when (exists && name `notElem` writtenNames) $
            removeFile path
    forM_ artifacts $ \(name, body) ->
        TIO.writeFile (outDir </> name) body
    pure writtenNames
  where
    knownExplainArtifacts =
        [ "parties.mmd"
        , "value-flow.tsv"
        , "topology.mmd"
        , "failures.mmd"
        , "summary.md"
        , "explain.md"
        ]
