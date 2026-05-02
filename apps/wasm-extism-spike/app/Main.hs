{- |
Module      : Main
Description : Reactor stub for the Extism plugin.

Empty 'main'. The wasm32-wasi reactor is started by Extism through
@hs_init@ and the exported plugin functions; this module exists only
to satisfy GHC's executable component.
-}
module Main (main) where

main :: IO ()
main = pure ()
