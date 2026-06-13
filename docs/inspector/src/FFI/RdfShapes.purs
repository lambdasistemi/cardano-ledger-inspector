module FFI.RdfShapes
  ( Json
  , ResolvedLabelRow
  , TransactionOutputRow
  , query
  , queryResolvedLabels
  , queryTransactionOutputs
  ) where

import Data.Either (Either(..))
import Effect (Effect)
import Foreign (Foreign)

type Json = Foreign

type TransactionOutputRow =
  { transaction :: String
  , txId :: String
  , outputs :: String
  }

type ResolvedLabelRow =
  { label :: String
  , role :: String
  , entity :: String
  , matched :: String
  }

foreign import queryImpl
  :: (String -> Either String Json)
  -> (Json -> Either String Json)
  -> String
  -> String
  -> Effect (Either String Json)

foreign import queryTransactionOutputsImpl
  :: (String -> Either String (Array TransactionOutputRow))
  -> (Array TransactionOutputRow -> Either String (Array TransactionOutputRow))
  -> String
  -> Effect (Either String (Array TransactionOutputRow))

foreign import queryResolvedLabelsImpl
  :: (String -> Either String (Array ResolvedLabelRow))
  -> (Array ResolvedLabelRow -> Either String (Array ResolvedLabelRow))
  -> String
  -> Effect (Either String (Array ResolvedLabelRow))

query :: String -> String -> Effect (Either String Json)
query = queryImpl Left Right

queryTransactionOutputs :: String -> Effect (Either String (Array TransactionOutputRow))
queryTransactionOutputs = queryTransactionOutputsImpl Left Right

queryResolvedLabels :: String -> Effect (Either String (Array ResolvedLabelRow))
queryResolvedLabels = queryResolvedLabelsImpl Left Right
