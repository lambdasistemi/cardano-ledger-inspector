{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Summary
Description : Top-level summary.md tying the cuts together with prose.

Sections, in fixed order so the file diffs cleanly:

* Title — from @intent.title@
* Verdict paragraph — combines @summary@, @valid_for_supplied_context@,
  and the failure count
* Claims — @intent.metadata_claims@ as a table
* Effects — @intent.sections[]@ rows (already pre-rendered for display
  by the inspector library)
* Signer perspective — @intent.signing@ + signer-perspective rows
* Validation failures — one row per failure
* Warnings — @intent.warnings@
* Diagrams — relative links to whatever cuts were emitted
-}
module TxDeepDiagnosisHost.Render.Summary (
    EmittedFiles (..),
    noEmittedFiles,
    renderSummaryMarkdown,
) where

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (foldl')
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Vector as V

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc (..))

{- | Which artifacts the caller wrote alongside @summary.md@.
Each Maybe holds the relative file name when written.
-}
data EmittedFiles = EmittedFiles
    { efParties :: !(Maybe FilePath)
    , efValueFlow :: !(Maybe FilePath)
    , efTopology :: !(Maybe FilePath)
    , efFailures :: !(Maybe FilePath)
    }

-- | Default 'EmittedFiles' with everything missing.
noEmittedFiles :: EmittedFiles
noEmittedFiles =
    EmittedFiles
        { efParties = Nothing
        , efValueFlow = Nothing
        , efTopology = Nothing
        , efFailures = Nothing
        }

renderSummaryMarkdown ::
    ProtocolRegistry ->
    DiagnosisDoc ->
    EmittedFiles ->
    Text
renderSummaryMarkdown _reg doc files =
    Text.concat
        [ titleSection doc
        , verdictSection doc
        , claimsSection doc
        , effectsSection doc
        , failuresSection doc
        , warningsSection doc
        , diagramsSection files
        ]

-- ---------------------------------------------------------------- --
-- Sections
-- ---------------------------------------------------------------- --

titleSection :: DiagnosisDoc -> Text
titleSection doc =
    let title = textPath doc ["result", "intent", "title"] "Transaction"
        subtitle =
            textPath
                doc
                ["result", "intent", "subtitle"]
                ""
     in "# "
            <> title
            <> "\n\n"
            <> ( if Text.null subtitle
                    then ""
                    else "_" <> subtitle <> "_\n\n"
               )
            <> "Tx id: `"
            <> textPath doc ["result", "intent", "tx_id"] ""
            <> "`\n\n"

verdictSection :: DiagnosisDoc -> Text
verdictSection doc =
    let topSummary = ddSummary doc
        valid =
            valuePath
                (ddValidate doc)
                [ "result"
                , "validation"
                , "valid_for_supplied_context"
                ]
        verdict = case valid of
            Just (Bool True) -> "valid"
            Just (Bool False) -> "invalid"
            _ -> "unknown"
     in "## Verdict\n\n"
            <> "- "
            <> topSummary
            <> "\n"
            <> "- ledger validation: **"
            <> verdict
            <> "**\n\n"

claimsSection :: DiagnosisDoc -> Text
claimsSection doc =
    let intent = ddIntent doc
        claims = case valuePath
            intent
            ["result", "intent", "claims"] of
            Just (Array xs) -> V.toList xs
            _ -> []
     in if null claims
            then ""
            else
                "## Claims\n\n"
                    <> "| Label | Value | Detail |\n"
                    <> "|-------|-------|--------|\n"
                    <> Text.concat (map renderClaim claims)
                    <> "\n"
  where
    renderClaim (Object o) =
        let lab = textOf "label" o ""
            val = textOf "value" o ""
            det = textOf "detail" o ""
         in "| "
                <> escapeTable lab
                <> " | "
                <> escapeTable val
                <> " | "
                <> escapeTable det
                <> " |\n"
    renderClaim _ = ""

effectsSection :: DiagnosisDoc -> Text
effectsSection doc =
    let intent = ddIntent doc
        sections = case valuePath
            intent
            ["result", "intent", "sections"] of
            Just (Array xs) -> V.toList xs
            _ -> []
     in Text.concat (map renderSectionHeading sections)
  where
    renderSectionHeading (Object o) =
        let title = textOf "title" o ""
            rows = case KeyMap.lookup "rows" o of
                Just (Array xs) -> V.toList xs
                _ -> []
            empty = textOf "empty" o ""
         in "## "
                <> title
                <> "\n\n"
                <> ( if null rows
                        then "_" <> empty <> "_\n\n"
                        else
                            "| Label | Value | Detail |\n"
                                <> "|-------|-------|--------|\n"
                                <> Text.concat (map renderRow rows)
                                <> "\n"
                   )
    renderSectionHeading _ = ""
    renderRow (Object o) =
        let lab = textOf "label" o ""
            val = textOf "value" o ""
            det = textOf "detail" o ""
         in "| "
                <> escapeTable lab
                <> " | "
                <> escapeTable val
                <> " | "
                <> escapeTable det
                <> " |\n"
    renderRow _ = ""

failuresSection :: DiagnosisDoc -> Text
failuresSection doc =
    let items = case valuePath
            (ddValidate doc)
            ["result", "validation", "failures"] of
            Just (Array xs) -> V.toList xs
            _ -> []
     in if null items
            then ""
            else
                "## Validation failures\n\n"
                    <> "| Rule | Message |\n"
                    <> "|------|---------|\n"
                    <> Text.concat (map renderFail items)
                    <> "\n"
  where
    renderFail (Object o) =
        let rule = textOf "rule" o ""
            msg = textOf "message" o ""
         in "| "
                <> escapeTable rule
                <> " | "
                <> escapeTable msg
                <> " |\n"
    renderFail _ = ""

warningsSection :: DiagnosisDoc -> Text
warningsSection doc =
    let warnings = case valuePath
            (ddIntent doc)
            ["result", "intent", "warnings"] of
            Just (Array xs) -> V.toList xs
            _ -> []
        textWarnings = [s | String s <- warnings]
     in if null textWarnings
            then ""
            else
                "## Warnings\n\n"
                    <> Text.concat (map (\w -> "- " <> w <> "\n") textWarnings)
                    <> "\n"

diagramsSection :: EmittedFiles -> Text
diagramsSection files =
    let entries =
            [ ("Parties (L1)", efParties files)
            , ("Value flow (L2, Sankey TSV)", efValueFlow files)
            , ("Topology (L3)", efTopology files)
            , ("Failures (L4)", efFailures files)
            ]
        present =
            [ "- [" <> label <> "](" <> Text.pack p <> ")\n"
            | (label, Just p) <- entries
            ]
     in if null present
            then ""
            else "## Diagrams\n\n" <> Text.concat present <> "\n"

-- ---------------------------------------------------------------- --
-- Helpers
-- ---------------------------------------------------------------- --

textOf :: Text -> KeyMap.KeyMap Value -> Text -> Text
textOf k o def = case KeyMap.lookup (Key.fromText k) o of
    Just (String s) -> s
    _ -> def

textPath :: DiagnosisDoc -> [Text] -> Text -> Text
textPath doc path def =
    let v =
            valuePath
                ( -- intent paths start with "result", validate paths
                  -- start with "result"; pick intent by default since
                  -- almost every textPath consumer wants the intent
                  -- subtree.
                  ddIntent doc
                )
                path
     in case v of
            Just (String s) -> s
            _ -> fromMaybe def (Just def)

valuePath :: Value -> [Text] -> Maybe Value
valuePath = foldl' step . Just
  where
    step (Just (Object o)) k = KeyMap.lookup (Key.fromText k) o
    step _ _ = Nothing

{- | Escape a text for safe inclusion in a Markdown table cell. Pipes
become escaped pipes; literal newlines collapse to spaces.
-}
escapeTable :: Text -> Text
escapeTable =
    Text.replace "\n" " "
        . Text.replace "|" "\\|"
