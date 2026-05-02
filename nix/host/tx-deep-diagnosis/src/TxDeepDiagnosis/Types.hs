{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosis.Types
    ( Hash28
    , Hash32
    , TxHash
    , OutRef (..)
    , Address (..)
    , Credential (..)
    , Lovelace
    , Asset (..)
    , Value (..)
    , adaOnly
    , addLovelace
    , Output (..)
    , Datum (..)
    , Cluster (..)
    , clusterKey
    , Network (..)
    , networkBaseUrl
    ) where

import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.ByteString.Base16 as B16
import qualified Data.Text.Encoding as TE

type Hash28 = ByteString
type Hash32 = ByteString
type TxHash = Hash32
type Lovelace = Integer

data OutRef = OutRef
    { outRefTx :: !TxHash
    , outRefIx :: !Int
    }
    deriving (Eq, Ord, Show)

data Credential
    = KeyCred !Hash28
    | ScriptCred !Hash28
    deriving (Eq, Ord, Show)

data Address = Address
    { addrPayment :: !Credential
    , addrStake :: !(Maybe Credential)
    , addrIsBootstrap :: !Bool
    }
    deriving (Eq, Ord, Show)

data Asset = Asset
    { assetPolicy :: !Hash28
    , assetName :: !ByteString
    }
    deriving (Eq, Ord, Show)

data Value = Value
    { valLovelace :: !Lovelace
    , valAssets :: !(Map Asset Integer)
    }
    deriving (Eq, Show)

adaOnly :: Lovelace -> Value
adaOnly l = Value l mempty

addLovelace :: Value -> Value -> Value
addLovelace a b = Value
    { valLovelace = valLovelace a + valLovelace b
    , valAssets = Map.unionWith (+) (valAssets a) (valAssets b)
    }

data Datum
    = NoDatum
    | DatumHash !Hash32
    | InlineDatum !ByteString
    deriving (Eq, Show)

data Output = Output
    { outAddress :: !Address
    , outValue :: !Value
    , outDatum :: !Datum
    , outScriptRefHash :: !(Maybe Hash28)
    }
    deriving (Eq, Show)

data Cluster = Cluster
    { clusterPayment :: !Credential
    , clusterStake :: !(Maybe Credential)
    , clusterMembers :: ![Int]
    , clusterTotal :: !Value
    }
    deriving (Eq, Show)

clusterKey :: Address -> (Credential, Maybe Credential)
clusterKey a = (addrPayment a, addrStake a)

data Network = Mainnet | Preprod | Preview
    deriving (Eq, Show)

networkBaseUrl :: Network -> Text
networkBaseUrl Mainnet = "https://cardano-mainnet.blockfrost.io/api/v0"
networkBaseUrl Preprod = "https://cardano-preprod.blockfrost.io/api/v0"
networkBaseUrl Preview = "https://cardano-preview.blockfrost.io/api/v0"
