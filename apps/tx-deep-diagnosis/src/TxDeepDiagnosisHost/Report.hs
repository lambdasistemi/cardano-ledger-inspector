{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosisHost.Report (
    buildReportValue,
    renderReport,
) where

import Data.Aeson (Value, (.=))
import qualified Data.Aeson as A
import qualified Data.Aeson.Encode.Pretty as APretty
import qualified Data.ByteString.Lazy as BSL
import Data.Text (Text)
import qualified Data.Text.Encoding as TE

import TxDeepDiagnosisHost.Registry (ProtocolRegistry)

buildReportValue ::
    Text ->
    Value ->
    Value ->
    Value
buildReportValue summary intent validate =
    A.object
        [ "tx-deep-diagnosis"
            .= A.object
                [ "summary" .= summary
                , "intent" .= intent
                , "validate" .= validate
                ]
        ]

{- | Render the diagnosis as one valid JSON document so the output
pipes cleanly into jq, can be saved as a fixture, etc.
-}
renderReport ::
    -- | summary line for the top of the document (resolution status, etc.)
    Text ->
    -- | tx.intent response from the inspector library
    Value ->
    -- | tx.validate response from the inspector library
    Value ->
    -- | the loaded protocol registry — included so the rendered report
    -- carries the labelling sources alongside the typed validation result
    ProtocolRegistry ->
    Text
renderReport summary intent validate _reg =
    TE.decodeUtf8
        (BSL.toStrict (APretty.encodePretty (buildReportValue summary intent validate)))
        <> "\n"
