{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosis.Blockfrost
    ( ResolvedOutput (..)
    , ResolvedAsset (..)
    , fetchTxUtxos
    , fetchTxExists
    , fetchOutputAtIndex
    ) where

import Control.Exception (try, SomeException)
import Data.Aeson (FromJSON (..), withObject, (.:), (.:?), (.!=), eitherDecode)
import qualified Data.Aeson as A
import qualified Data.Aeson.Types as A
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as BSL
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Network.HTTP.Client
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Header (hAccept)
import Network.HTTP.Types.Status (statusCode)

import TxDeepDiagnosis.Types

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
    parseJSON = withObject "ResolvedOutput" $ \o -> do
        ix <- o .: "output_index"
        addr <- o .: "address"
        assets <- o .: "amount"
        inlineDatum <- o .:? "inline_datum"
        dataHash <- o .:? "data_hash"
        scriptRef <- o .:? "reference_script_hash"
        pure ResolvedOutput
            { rOutIx = ix
            , rOutAddress = addr
            , rOutAssets = assets
            , rOutInlineDatum = inlineDatum
            , rOutDataHash = dataHash
            , rOutScriptRefHash = scriptRef
            }

data UtxosResponse = UtxosResponse
    { urInputsCount :: !Int
    , urOutputs :: ![ResolvedOutput]
    }

instance FromJSON UtxosResponse where
    parseJSON = withObject "UtxosResponse" $ \o -> do
        ins <- o .:? "inputs" .!= []
        outs <- o .:? "outputs" .!= []
        let _ = (ins :: [A.Value])
        pure UtxosResponse { urInputsCount = length ins, urOutputs = outs }

fetchTxUtxos :: Manager -> Network -> Text -> Text -> IO (Either String [ResolvedOutput])
fetchTxUtxos mgr net pid txHash = do
    let url = networkBaseUrl net <> "/txs/" <> txHash <> "/utxos"
    result <- try (callBlockfrost mgr url pid) :: IO (Either SomeException (Either String BSL.ByteString))
    case result of
        Left e -> pure $ Left ("HTTP error: " <> show e)
        Right (Left e) -> pure $ Left e
        Right (Right body) -> case eitherDecode body of
            Left e -> pure $ Left ("JSON decode error: " <> e)
            Right (UtxosResponse _ outs) -> pure $ Right outs

fetchTxExists :: Manager -> Network -> Text -> Text -> IO Bool
fetchTxExists mgr net pid txHash = do
    let url = networkBaseUrl net <> "/txs/" <> txHash
    result <- try (callBlockfrost mgr url pid) :: IO (Either SomeException (Either String BSL.ByteString))
    case result of
        Right (Right _) -> pure True
        _ -> pure False

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
    initReq <- parseUrlThrow (Text.unpack url)
    let req = initReq
            { requestHeaders = [(hAccept, "application/json"), ("project_id", TE.encodeUtf8 pid)]
            , method = "GET"
            }
    resp <- httpLbs req mgr
    let code = statusCode (responseStatus resp)
    if code == 200
        then pure $ Right (responseBody resp)
        else pure $ Left ("Blockfrost " <> show code <> ": " <> Text.unpack url)
