{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Main
Description : Native Haskell host for the Extism PDK spike.

Loads the wasm-extism-spike plugin via libextism (Wasmtime-backed),
calls a named export with bytes read from stdin, and writes the
plugin's output bytes to stdout.

Invocation:

>     extism-spike-host PATH-TO-WASM [FUNCTION] < input > out

@FUNCTION@ defaults to @tx_identify@. Errors from the runtime go to
stderr with a non-zero exit code.
-}
module Main (main) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BSL
import qualified Extism
import qualified Extism.Manifest as Manifest
import System.Environment (getArgs)
import System.Exit (die, exitSuccess)
import System.IO (hPutStrLn, stderr, stdout)

main :: IO ()
main = do
    args <- getArgs
    (pluginPath, function) <- case args of
        [path] -> pure (path, "tx_identify")
        [path, fn] -> pure (path, fn)
        _ -> die "usage: extism-spike-host PATH-TO-WASM [FUNCTION]"
    let manifest = Manifest.manifest [Manifest.wasmFile pluginPath]
    plugin <- Extism.newPlugin manifest [] True >>= unwrap
    payload <- BS.getContents
    response <- Extism.call plugin function payload >>= unwrap
    BSL.hPut stdout (BSL.fromStrict response)
    BSL.hPut stdout "\n"
    exitSuccess

unwrap :: Either Extism.Error a -> IO a
unwrap (Right a) = pure a
unwrap (Left (Extism.ExtismError msg)) = do
    hPutStrLn stderr ("extism error: " <> msg)
    die "extism call failed"
