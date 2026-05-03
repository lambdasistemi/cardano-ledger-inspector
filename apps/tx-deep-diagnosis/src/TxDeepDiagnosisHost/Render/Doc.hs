{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Doc
Description : Typed view onto the tx-deep-diagnosis JSON envelope.

The envelope produced by 'TxDeepDiagnosisHost.Report.renderReport' wraps
a @tx-deep-diagnosis@ object with @summary@, @intent@ and @validate@
children. Renderers operate on this typed view rather than walking the
raw 'A.Value' from the top.
-}
module TxDeepDiagnosisHost.Render.Doc (
    DiagnosisDoc (..),
    parseDiagnosisDoc,
) where

import Data.Aeson (Value)
import qualified Data.Aeson as A
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Text (Text)

-- | Parsed @tx-deep-diagnosis@ envelope.
data DiagnosisDoc = DiagnosisDoc
    { ddSummary :: !Text
    -- ^ Top-level summary line ("N/M producer txs resolved, network=…").
    , ddIntent :: !Value
    -- ^ Raw @intent@ subobject as returned by @tx.intent@.
    , ddValidate :: !Value
    -- ^ Raw @validate@ subobject as returned by @tx.validate@.
    }
    deriving (Show)

{- | Parse a 'DiagnosisDoc' out of the wrapped envelope JSON. Accepts
either the wrapped form @{"tx-deep-diagnosis": {...}}@ or the inner
object directly so this is robust to minor format drift.
-}
parseDiagnosisDoc :: Value -> Either String DiagnosisDoc
parseDiagnosisDoc raw = case raw of
    A.Object root
        | Just (A.Object inner) <- KeyMap.lookup "tx-deep-diagnosis" root ->
            fromInner inner
        | otherwise -> fromInner root
    _ -> Left "tx-deep-diagnosis envelope must be a JSON object"
  where
    fromInner inner = do
        summary <- requireText "summary" inner
        intent <- requireValue "intent" inner
        validate <- requireValue "validate" inner
        Right
            DiagnosisDoc
                { ddSummary = summary
                , ddIntent = intent
                , ddValidate = validate
                }

requireValue :: KeyMap.Key -> KeyMap.KeyMap Value -> Either String Value
requireValue k m = case KeyMap.lookup k m of
    Just v -> Right v
    Nothing -> Left ("missing field: " <> show k)

requireText :: KeyMap.Key -> KeyMap.KeyMap Value -> Either String Text
requireText k m = case KeyMap.lookup k m of
    Just (A.String t) -> Right t
    Just _ -> Left ("field is not a string: " <> show k)
    Nothing -> Left ("missing field: " <> show k)
