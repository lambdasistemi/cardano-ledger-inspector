{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Single
Description : Single-file markdown with all cuts embedded inline.

Same content as the directory-shaped explain artifacts, assembled into one
self-contained document. The summary stays reader-first; the Mermaid diagrams
follow at the end behind collapsed @<details>@ blocks so they are available
without dominating the first screen.
-}
module TxDeepDiagnosisHost.Render.Single (
    renderSingleMarkdown,
) where

import Data.Text (Text)
import qualified Data.Text as Text

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc)
import TxDeepDiagnosisHost.Render.Failures (renderFailuresMermaid)
import TxDeepDiagnosisHost.Render.Parties (renderPartiesMermaid)
import TxDeepDiagnosisHost.Render.Summary (
    EmittedFiles (..),
    renderSummaryMarkdown,
 )
import TxDeepDiagnosisHost.Render.Topology (renderTopologyMermaid)

{- | Render the whole explain bundle into a single markdown document.
The diagrams footer in the shared summary is suppressed because the diagrams
follow inline in collapsed blocks.
-}
renderSingleMarkdown :: ProtocolRegistry -> DiagnosisDoc -> Text
renderSingleMarkdown reg doc =
    Text.concat
        [ summaryWithoutFooter reg doc
        , partiesBlock reg doc
        , topologyBlock reg doc
        , failuresBlock reg doc
        ]

summaryWithoutFooter :: ProtocolRegistry -> DiagnosisDoc -> Text
summaryWithoutFooter reg doc =
    renderSummaryMarkdown reg doc emptyFiles
  where
    emptyFiles =
        EmittedFiles
            { efParties = Nothing
            , efValueFlow = Nothing
            , efTopology = Nothing
            , efFailures = Nothing
            }

partiesBlock :: ProtocolRegistry -> DiagnosisDoc -> Text
partiesBlock reg doc =
    detailsMermaidBlock "Parties" (renderPartiesMermaid reg doc)

topologyBlock :: ProtocolRegistry -> DiagnosisDoc -> Text
topologyBlock reg doc =
    detailsMermaidBlock "Topology" (renderTopologyMermaid reg doc)

failuresBlock :: ProtocolRegistry -> DiagnosisDoc -> Text
failuresBlock reg doc = case renderFailuresMermaid reg doc of
    Nothing -> ""
    Just body -> detailsMermaidBlock "Failure overlay" body

detailsMermaidBlock :: Text -> Text -> Text
detailsMermaidBlock label body =
    "<details><summary>"
        <> label
        <> "</summary>\n\n```mermaid\n"
        <> body
        <> "```\n\n</details>\n\n"
