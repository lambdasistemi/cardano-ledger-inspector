{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

{- |
Module      : Extism.Spike
Description : Extism PDK plugin exposing one ledger operation.

Single export: 'tx_identify'. Reads a hex-encoded Conway transaction
from the Extism plugin input, decodes it through
'cardano-ledger-conway', and writes a small identification JSON
(tx_id, input_count, output_count, fee_lovelace, tx_size_bytes) to
the plugin output.

Slice — not byte-parity — of the WASI reactor's @tx.identify@. The
spike answers "can the Conway closure co-exist with the Extism PDK
in one wasm32-wasi binary?" not "is the Extism response byte-
identical to the WASI response?". Byte parity is a follow-up.
-}
module Extism.Spike (tx_identify) where

import qualified Cardano.Crypto.Hash as Crypto
import qualified Cardano.Ledger.Api as L
import qualified Cardano.Ledger.Binary as Binary
import qualified Cardano.Ledger.Coin as Coin
import qualified Cardano.Ledger.Conway as Conway
import Cardano.Ledger.Core (TxLevel (..))
import qualified Cardano.Ledger.Core as Core
import qualified Cardano.Ledger.Hashes as Hashes
import qualified Cardano.Ledger.TxIn as TxIn
import Data.Aeson ((.=))
import qualified Data.Aeson as Aeson
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as Base16
import qualified Data.ByteString.Lazy as BSL
import Data.Foldable (toList)
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import Extism.PDK (inputByteString, output, setError)
import Lens.Micro ((^.))

-- | Plugin entry point.
tx_identify :: IO ()
tx_identify = do
    payload <- inputByteString
    case identify payload of
        Right value -> output (BSL.toStrict (Aeson.encode value))
        Left err -> setError (T.unpack err)

identify :: BS.ByteString -> Either T.Text Aeson.Value
identify hexInput = do
    raw <- decodeHex (stripWhitespace hexInput)
    tx <- decodeTx raw
    pure (identifyJson raw tx)

stripWhitespace :: BS.ByteString -> BS.ByteString
stripWhitespace =
    BS.filter
        (\c -> c /= 0x20 && c /= 0x09 && c /= 0x0a && c /= 0x0d)

decodeHex :: BS.ByteString -> Either T.Text BS.ByteString
decodeHex bytes = case Base16.decode bytes of
    Right ok -> Right ok
    Left err -> Left ("malformed_hex: " <> T.pack err)

decodeTx ::
    BS.ByteString ->
    Either T.Text (L.Tx TopTx Conway.ConwayEra)
decodeTx bytes =
    case Binary.decodeFullAnnotator
        (Core.eraProtVerLow @Conway.ConwayEra)
        "ConwayTx"
        Binary.decCBOR
        (BSL.fromStrict bytes) of
        Right tx -> Right tx
        Left err -> Left ("malformed_cbor: " <> T.pack (show err))

identifyJson ::
    BS.ByteString ->
    L.Tx TopTx Conway.ConwayEra ->
    Aeson.Value
identifyJson rawBytes tx =
    let body = tx ^. L.bodyTxL
        inputs = toList (body ^. L.inputsTxBodyL)
        outputs = toList (body ^. L.outputsTxBodyL)
     in Aeson.object
            [ "era" .= ("Conway" :: T.Text)
            , "tx_id" .= txIdHex (Core.txIdTx tx)
            , "tx_size_bytes" .= BS.length rawBytes
            , "fee_lovelace"
                .= T.pack (show (Coin.unCoin (body ^. L.feeTxBodyL)))
            , "input_count" .= length inputs
            , "output_count" .= length outputs
            ]

txIdHex :: TxIn.TxId -> T.Text
txIdHex (TxIn.TxId safeHash) =
    hashHex (Hashes.extractHash safeHash)

hashHex :: Crypto.Hash h a -> T.Text
hashHex = T.decodeUtf8 . Base16.encode . Crypto.hashToBytes

foreign export ccall "tx_identify" tx_identify :: IO ()
