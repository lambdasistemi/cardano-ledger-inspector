{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosisHost.Report
    ( renderTopLevel
    ) where

import Data.Aeson (Value)
import qualified Data.Aeson.Encode.Pretty as APretty
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Data.Text (Text)

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)

renderTopLevel :: Text -> Value -> Value -> ProtocolRegistry -> Text
renderTopLevel title intent validate _reg = Text.unlines
    [ bar title
    , bar "tx.intent (raw from cardano-ledger-conway via wasm-tx-inspector lib)"
    , prettyJson intent
    , bar "tx.validate (real applyTx via cardano-ledger-conway)"
    , prettyJson validate
    ]
  where
    bar t = Text.replicate 78 "=" <> "\n  " <> t <> "\n"
        <> Text.replicate 78 "="

prettyJson :: Value -> Text
prettyJson = TE.decodeUtf8 . BSL.toStrict . APretty.encodePretty
