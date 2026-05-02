{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosis.Diagnosis
    ( Diagnosis (..)
    , ResolvedInput (..)
    , BalanceCheck (..)
    , runDiagnosis
    , credToText
    , hashHex
    ) where

import Control.Monad (forM)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Char8 as BC
import Data.Function (on)
import Data.List (groupBy, nub, sortBy)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, fromMaybe, mapMaybe)
import Data.Ord (Down (..), comparing)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Network.HTTP.Client (Manager)

import TxDeepDiagnosis.Blockfrost
import TxDeepDiagnosis.Conway
import TxDeepDiagnosis.Registry
import TxDeepDiagnosis.Types

data ResolvedInput = ResolvedInput
    { riOutRef :: !OutRef
    , riAddressText :: !(Maybe Text)
    , riValueLovelace :: !(Maybe Lovelace)
    , riError :: !(Maybe Text)
    , riExists :: !Bool
    }
    deriving (Show)

data Diagnosis = Diagnosis
    { dgTx :: !DecodedTx
    , dgResolvedInputs :: ![ResolvedInput]
    , dgResolvedCollateral :: ![ResolvedInput]
    , dgClusters :: ![Cluster]
    , dgScriptIdentifications :: ![(Hash28, Identification)]
    , dgRefInputIdentifications :: ![(OutRef, Maybe (AmaruScope, Text))]
    , dgRequiredSignerScopes :: ![(Hash28, Maybe AmaruScope)]
    , dgDatumExtractedHashes :: !(Map Int [Hash28])
    , dgBalanceCheck :: !BalanceCheck
    }

data BalanceCheck = BalanceCheck
    { bcTotalIn :: !Lovelace
    , bcTotalOut :: !Lovelace
    , bcFee :: !Lovelace
    , bcWithdrawals :: !Lovelace
    , bcDelta :: !Lovelace
    , bcResolvedInputCount :: !Int
    , bcExpectedInputCount :: !Int
    , bcCollateralResolved :: !Bool
    , bcCollateralExists :: !Bool
    }

runDiagnosis
    :: Manager
    -> Network
    -> Maybe Text
    -> ProtocolRegistry
    -> DecodedTx
    -> IO Diagnosis
runDiagnosis mgr net mpid reg tx = do
    resolved <- mapM (resolveInput mgr net mpid) (txInputs tx)
    resolvedColl <- mapM (resolveInput mgr net mpid) (txCollateralInputs tx)
    let clusters = computeClusters (txOutputs tx)
        scriptIds = identifyAllScripts reg tx
        refIds = case prAmaru reg of
            Just j -> map (refLookup j) (txReferenceInputs tx)
            Nothing -> [(o, Nothing) | o <- txReferenceInputs tx]
        signerScopes = case prAmaru reg of
            Just j -> [(s, findScopeByOwner j (TE.decodeUtf8 (B16.encode s))) | s <- txRequiredSigners tx]
            Nothing -> [(s, Nothing) | s <- txRequiredSigners tx]
        extracted = Map.fromList
            [ (i, extractDatumHashes b)
            | (i, o) <- zip [1 :: Int ..] (txOutputs tx)
            , InlineDatum b <- [outDatum o]
            ]
        bc = balanceCheck tx resolved resolvedColl
    pure Diagnosis
        { dgTx = tx
        , dgResolvedInputs = resolved
        , dgResolvedCollateral = resolvedColl
        , dgClusters = clusters
        , dgScriptIdentifications = scriptIds
        , dgRefInputIdentifications = refIds
        , dgRequiredSignerScopes = signerScopes
        , dgDatumExtractedHashes = extracted
        , dgBalanceCheck = bc
        }
  where
    refLookup j outref =
        let outrefText = hashHex (outRefTx outref) <> "#" <> Text.pack (zeroPad (outRefIx outref))
        in (outref, findScopeByRefOutref j outrefText)
    zeroPad n
        | n < 10 = "0" <> show n
        | otherwise = show n

resolveInput :: Manager -> Network -> Maybe Text -> OutRef -> IO ResolvedInput
resolveInput _ _ Nothing outref = pure ResolvedInput
    { riOutRef = outref
    , riAddressText = Nothing, riValueLovelace = Nothing
    , riError = Just "no Blockfrost project_id provided", riExists = False
    }
resolveInput mgr net (Just pid) outref = do
    let txHashHex = hashHex (outRefTx outref)
    eOut <- fetchOutputAtIndex mgr net pid txHashHex (outRefIx outref)
    case eOut of
        Left err -> pure ResolvedInput
            { riOutRef = outref, riAddressText = Nothing
            , riValueLovelace = Nothing
            , riError = Just (Text.pack err), riExists = False
            }
        Right Nothing -> pure ResolvedInput
            { riOutRef = outref, riAddressText = Nothing
            , riValueLovelace = Nothing
            , riError = Just "output index not found at producer tx (UTxO does not exist)"
            , riExists = False
            }
        Right (Just out) ->
            let lovelace = case [rAssetQty a | a <- rOutAssets out, rAssetUnit a == "lovelace"] of
                    (l:_) -> Just l
                    [] -> Nothing
            in pure ResolvedInput
                { riOutRef = outref
                , riAddressText = Just (rOutAddress out)
                , riValueLovelace = lovelace
                , riError = Nothing
                , riExists = True
                }

computeClusters :: [Output] -> [Cluster]
computeClusters outs =
    let indexed = zip [1..] outs
        keyOf (_, o) = clusterKey (outAddress o)
        sorted = sortBy (comparing keyOf) indexed
        grouped = groupBy ((==) `on` keyOf) sorted
        mkCluster grp = case grp of
            ((_, o):_) ->
                let (p, s) = clusterKey (outAddress o)
                    members = map fst grp
                    total = foldr addLovelace (adaOnly 0) (map (outValue . snd) grp)
                in Just Cluster
                    { clusterPayment = p, clusterStake = s
                    , clusterMembers = members, clusterTotal = total
                    }
            [] -> Nothing
    in mapMaybe mkCluster grouped

identifyAllScripts :: ProtocolRegistry -> DecodedTx -> [(Hash28, Identification)]
identifyAllScripts reg tx =
    let scriptHashes = nub $ concatMap outputScriptHashes (txOutputs tx)
                         ++ withdrawalScriptHashes (txWithdrawals tx)
    in [(h, identifyByHash reg h) | h <- scriptHashes]

outputScriptHashes :: Output -> [Hash28]
outputScriptHashes o =
    let payment = case addrPayment (outAddress o) of
            ScriptCred h -> [h]
            _ -> []
        stake = case addrStake (outAddress o) of
            Just (ScriptCred h) -> [h]
            _ -> []
    in payment ++ stake

withdrawalScriptHashes :: [(Credential, Lovelace)] -> [Hash28]
withdrawalScriptHashes ws = [h | (ScriptCred h, _) <- ws]

balanceCheck :: DecodedTx -> [ResolvedInput] -> [ResolvedInput] -> BalanceCheck
balanceCheck tx resolved resolvedColl =
    let inLs = catMaybes (map riValueLovelace resolved)
        totalIn = sum inLs
        totalOut = sum (map (valLovelace . outValue) (txOutputs tx))
        wdsum = sum (map snd (txWithdrawals tx))
        delta = totalIn - totalOut - txFee tx + wdsum
        collExists = case resolvedColl of
            (r:_) -> riExists r
            [] -> True
    in BalanceCheck
        { bcTotalIn = totalIn
        , bcTotalOut = totalOut
        , bcFee = txFee tx
        , bcWithdrawals = wdsum
        , bcDelta = delta
        , bcResolvedInputCount = length inLs
        , bcExpectedInputCount = length (txInputs tx)
        , bcCollateralResolved = not (null resolvedColl)
        , bcCollateralExists = collExists
        }

credToText :: Credential -> Text
credToText (KeyCred h) = "key(" <> shortHash h <> ")"
credToText (ScriptCred h) = "script(" <> shortHash h <> ")"

shortHash :: BS.ByteString -> Text
shortHash h =
    let hh = TE.decodeUtf8 (B16.encode h)
        n = Text.length hh
    in if n <= 16 then hh else Text.take 8 hh <> "…" <> Text.takeEnd 4 hh

hashHex :: BS.ByteString -> Text
hashHex = TE.decodeUtf8 . B16.encode
