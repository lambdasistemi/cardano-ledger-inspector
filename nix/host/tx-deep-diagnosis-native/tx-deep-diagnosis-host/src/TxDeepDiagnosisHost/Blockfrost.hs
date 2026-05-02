{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosisHost.Blockfrost
    ( Network (..)
    , networkBaseUrl
    , ResolvedOutput (..)
    , ResolvedAsset (..)
    , fetchTxUtxos
    , fetchTxCbor
    , fetchOutputAtIndex
    ) where

import Control.Exception (try, SomeException)
import Data.Aeson (FromJSON (..), withObject, (.:), (.:?), (.!=), eitherDecode)
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BSL
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Network.HTTP.Client
import Network.HTTP.Types.Header (hAccept)
import Network.HTTP.Types.Status (statusCode)

data Network = Mainnet | Preprod | Preview
    deriving (Eq, Show)

networkBaseUrl :: Network -> Text
networkBaseUrl Mainnet = "https://cardano-mainnet.blockfrost.io/api/v0"
networkBaseUrl Preprod = "https://cardano-preprod.blockfrost.io/api/v0"
networkBaseUrl Preview = "https://cardano-preview.blockfrost.io/api/v0"

data ResolvedAsset = ResolvedAsset
    { rAssetUnit :: !Text
    , rAssetQty :: !Integer
    }
    deriving (Show)

data ResolvedOutput = ResolvedOutput
    { rOutIx :: !Int
    , rOutAddress :: !Text
    , rOutAssets :: ![ResolvedAsset]
    , rOutInlineDatum :: !(Maybe Text)
    , rOutDataHash :: !(Maybe Text)
    , rOutScriptRefHash :: !(Maybe Text)
    }
    deriving (Show)

instance FromJSON ResolvedAsset where
    parseJSON = withObject "ResolvedAsset" $ \o -> do
        unit <- o .: "unit"
        qtyStr <- o .: "quantity"
        qty <- case Text.unpack qtyStr of
            s -> case reads s of
                [(n, "")] -> pure n
                _ -> fail ("bad quantity: " <> s)
        pure ResolvedAsset { rAssetUnit = unit, rAssetQty = qty }

instance FromJSON ResolvedOutput where
    parseJSON = withObject "ResolvedOutput" $ \o ->
        ResolvedOutput
            <$> o .: "output_index"
            <*> o .: "address"
            <*> o .: "amount"
            <*> o .:? "inline_datum"
            <*> o .:? "data_hash"
            <*> o .:? "reference_script_hash"

data UtxosResponse = UtxosResponse { urOutputs :: ![ResolvedOutput] }

instance FromJSON UtxosResponse where
    parseJSON = withObject "UtxosResponse" $ \o ->
        UtxosResponse <$> o .:? "outputs" .!= []

data CborResponse = CborResponse { crCbor :: !Text }

instance FromJSON CborResponse where
    parseJSON = withObject "CborResponse" $ \o -> CborResponse <$> o .: "cbor"

fetchTxUtxos :: Manager -> Network -> Text -> Text -> IO (Either String [ResolvedOutput])
fetchTxUtxos mgr net pid txHash = do
    let url = networkBaseUrl net <> "/txs/" <> txHash <> "/utxos"
    eBody <- callBlockfrost mgr url pid
    pure $ case eBody of
        Left e -> Left e
        Right body -> case eitherDecode body of
            Left e -> Left ("JSON decode error: " <> e)
            Right (UtxosResponse outs) -> Right outs

fetchTxCbor :: Manager -> Network -> Text -> Text -> IO (Either String Text)
fetchTxCbor mgr net pid txHash = do
    let url = networkBaseUrl net <> "/txs/" <> txHash <> "/cbor"
    eBody <- callBlockfrost mgr url pid
    pure $ case eBody of
        Left e -> Left e
        Right body -> case eitherDecode body of
            Left e -> Left ("JSON decode error: " <> e)
            Right (CborResponse h) -> Right h

fetchOutputAtIndex
    :: Manager
    -> Network
    -> Text
    -> Text
    -> Int
    -> IO (Either String (Maybe ResolvedOutput))
fetchOutputAtIndex mgr net pid txHash ix = do
    eOuts <- fetchTxUtxos mgr net pid txHash
    pure $ fmap (\outs -> case [o | o <- outs, rOutIx o == ix] of
        (o:_) -> Just o
        [] -> Nothing) eOuts

callBlockfrost :: Manager -> Text -> Text -> IO (Either String BSL.ByteString)
callBlockfrost mgr url pid = do
    eResult <- try (do
        initReq <- parseUrlThrow (Text.unpack url)
        let req = initReq
                { requestHeaders = [(hAccept, "application/json"), ("project_id", TE.encodeUtf8 pid)]
                , method = "GET"
                }
        resp <- httpLbs req mgr
        let code = statusCode (responseStatus resp)
        if code == 200
            then pure $ Right (responseBody resp)
            else pure $ Left ("Blockfrost " <> show code <> ": " <> Text.unpack url))
        :: IO (Either SomeException (Either String BSL.ByteString))
    case eResult of
        Left e -> pure $ Left ("HTTP error: " <> show e)
        Right r -> pure r
