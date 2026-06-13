module FFI.OverlayBook
  ( OverlayBook
  , OverlayPart
  , bundledAmaruJournal
  , parse
  ) where

import Data.Either (Either(..))
import Effect (Effect)

type OverlayPart =
  { id :: String
  , label :: String
  , turtle :: String
  }

type OverlayBook =
  { title :: String
  , source :: String
  , parts :: Array OverlayPart
  , turtle :: String
  }

foreign import bundledAmaruJournal :: String

foreign import parseImpl
  :: (String -> Either String OverlayBook)
  -> (OverlayBook -> Either String OverlayBook)
  -> String
  -> Effect (Either String OverlayBook)

parse :: String -> Effect (Either String OverlayBook)
parse = parseImpl Left Right
