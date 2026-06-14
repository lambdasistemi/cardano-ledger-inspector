module Routing
  ( Route(..)
  , currentRoute
  , routePath
  , pushRoute
  ) where

import Prelude

import Effect (Effect)

data Route
  = RouteInspect
  | RouteSettings
  | RouteLibrary

derive instance eqRoute :: Eq Route

routePath :: Route -> String
routePath = case _ of
  RouteInspect -> "/inspect"
  RouteSettings -> "/settings"
  RouteLibrary -> "/library"

currentRoute :: Effect Route
currentRoute = do
  path <- _pathname
  pure case path of
    "/settings" -> RouteSettings
    "/settings/" -> RouteSettings
    "/library" -> RouteLibrary
    "/library/" -> RouteLibrary
    _ -> RouteInspect

pushRoute :: Route -> Effect Unit
pushRoute = _pushPath <<< routePath

foreign import _pathname :: Effect String
foreign import _pushPath :: String -> Effect Unit
