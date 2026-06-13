module FFI.RdfShapes
  ( Json
  , query
  ) where

import Data.Either (Either(..))
import Effect (Effect)
import Foreign (Foreign)

type Json = Foreign

foreign import queryImpl
  :: (String -> Either String Json)
  -> (Json -> Either String Json)
  -> String
  -> String
  -> Effect (Either String Json)

query :: String -> String -> Effect (Either String Json)
query = queryImpl Left Right
