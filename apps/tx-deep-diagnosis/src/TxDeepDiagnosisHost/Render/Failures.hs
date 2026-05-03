{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Failures
Description : L4 cut — failures-only Mermaid diagram, when invalid.

Returns 'Nothing' when @validation.failures@ is empty so callers know
not to write the file. When non-empty: emits a small Mermaid
@flowchart TD@ with one node per failure routed onto its target node
(body, signer, or input) per the same mapping used by 'Render.Topology'.
-}
module TxDeepDiagnosisHost.Render.Failures (
    renderFailuresMermaid,
) where

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (foldl')
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Builder as TB
import qualified Data.Vector as V

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)
import TxDeepDiagnosisHost.Render.Doc (DiagnosisDoc (..))
import TxDeepDiagnosisHost.Render.Names (truncateHash)

-- | Render a Mermaid failures diagram, or 'Nothing' when valid.
renderFailuresMermaid :: ProtocolRegistry -> DiagnosisDoc -> Maybe Text
renderFailuresMermaid _reg doc =
    let failures = failureItems doc
     in if null failures
            then Nothing
            else
                Just
                    . TL.toStrict
                    . TB.toLazyText
                    . mconcat
                    $ [ "%% L4 — failures for tx "
                      , txt (txIdOf doc)
                      , "\n"
                      , "flowchart TD\n"
                      , "    classDef body fill:#fff,stroke:#000\n"
                      , "    classDef bodyFail fill:#ffe6e6,stroke:#cc0000,stroke-width:2px\n"
                      , "    classDef signerFail fill:#ffe6e6,stroke:#cc0000,stroke-width:2px\n"
                      , "    classDef ruleFail fill:#fff0f0,stroke:#aa3333,stroke-dasharray:3 3\n"
                      , "    body[\"tx body\"]:::body\n"
                      , mconcat (zipWith (renderFailure doc) [0 ..] failures)
                      ]

renderFailure :: DiagnosisDoc -> Int -> FailureItem -> TB.Builder
renderFailure doc i fi =
    let tag = "f" <> txt (Text.pack (show i))
        ruleNode =
            mconcat
                [ "    "
                , tag
                , "[\""
                , txt (escape (fiTitle fi))
                , "\"]:::ruleFail\n"
                ]
     in case fiClass fi of
            BodyFail ->
                ruleNode
                    <> mconcat ["    ", tag, " --> body\n"]
                    <> "    body:::bodyFail\n"
            SignerFail hashes ->
                let signerNodes =
                        zipWith
                            (renderSignerNode tag)
                            [0 :: Int ..]
                            hashes
                 in ruleNode <> mconcat signerNodes
  where
    _unused = doc

renderSignerNode :: TB.Builder -> Int -> Text -> TB.Builder
renderSignerNode parent j h =
    let tag = parent <> "_s" <> txt (Text.pack (show j))
        label = "missing signer " <> truncateHash h
     in mconcat
            [ "    "
            , tag
            , "[\""
            , txt (escape label)
            , "\"]:::signerFail\n    "
            , parent
            , " --> "
            , tag
            , "\n"
            ]

-- ---------------------------------------------------------------- --
-- Failure parsing
-- ---------------------------------------------------------------- --

data FailureClass
    = BodyFail
    | SignerFail ![Text]
    deriving (Show)

data FailureItem = FailureItem
    { fiTitle :: !Text
    , fiClass :: !FailureClass
    }

failureItems :: DiagnosisDoc -> [FailureItem]
failureItems doc =
    let path = ["result", "validation", "failures"]
        items = case lookupPath (ddValidate doc) path of
            Just (Array xs) -> V.toList xs
            _ -> []
     in map parseItem items
  where
    parseItem (Object o) =
        let predicate = fromMaybe "" (textOf "predicate" o)
            rule = fromMaybe "" (textOf "rule" o)
            short = shortName predicate
            cls
                | "MissingVKeyWitnesses" `Text.isInfixOf` predicate =
                    SignerFail (extractKeyHashes predicate)
                | otherwise = BodyFail
         in FailureItem
                { fiTitle = rule <> " / " <> short
                , fiClass = cls
                }
    parseItem _ =
        FailureItem{fiTitle = "unknown failure shape", fiClass = BodyFail}

textOf :: Text -> KeyMap.KeyMap Value -> Maybe Text
textOf k o = case KeyMap.lookup (Key.fromText k) o of
    Just (String s) -> Just s
    _ -> Nothing

-- | Collapse a verbose ledger predicate to a short, displayable name.
shortName :: Text -> Text
shortName p
    | "ValueNotConservedUTxO" `Text.isInfixOf` p = "ValueNotConservedUTxO"
    | "MissingVKeyWitnesses" `Text.isInfixOf` p = "MissingVKeyWitnesses"
    | "BadInputsUTxO" `Text.isInfixOf` p = "BadInputsUTxO"
    | "OutsideValidityIntervalUTxO" `Text.isInfixOf` p = "OutsideValidityInterval"
    | otherwise = Text.take 60 p

extractKeyHashes :: Text -> [Text]
extractKeyHashes =
    filter isHashLike
        . map cleanup
        . drop 1
        . Text.splitOn "KeyHash"
  where
    cleanup t =
        Text.takeWhile
            (/= '"')
            (Text.drop 1 (Text.dropWhile (/= '"') t))
    isHashLike t =
        Text.length t == 56 && Text.all isHex t
    isHex c =
        (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')

-- ---------------------------------------------------------------- --
-- Helpers
-- ---------------------------------------------------------------- --

txIdOf :: DiagnosisDoc -> Text
txIdOf doc = case lookupPath (ddIntent doc) ["result", "intent", "tx_id"] of
    Just (String s) -> s
    _ -> ""

lookupPath :: Value -> [Text] -> Maybe Value
lookupPath = foldl' step . Just
  where
    step (Just (Object o)) k = KeyMap.lookup (Key.fromText k) o
    step _ _ = Nothing

txt :: Text -> TB.Builder
txt = TB.fromText

escape :: Text -> Text
escape = Text.replace "\"" "\\\""
