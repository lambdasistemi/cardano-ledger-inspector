module Provider
  ( Provider(..)
  , providerName
  , needsKey
  , fetchTxCbor
  , resolveProducerTxContext
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Effect (Effect)
import Effect.Aff (Aff)
import FFI.Blockfrost (Network)
import FFI.Blockfrost as Blockfrost
import FFI.Koios as Koios

data Provider = Blockfrost | Koios

derive instance eqProvider :: Eq Provider

providerName :: Provider -> String
providerName = case _ of
  Blockfrost -> "Blockfrost"
  Koios      -> "Koios"

-- | Blockfrost requires a project ID. Koios accepts an optional bearer
-- token for higher rate limits; it works without one, so the key field
-- is optional.
needsKey :: Provider -> Boolean
needsKey = case _ of
  Blockfrost -> true
  Koios      -> false

-- | Unified fetch. `key` is the project ID for Blockfrost or an optional
-- bearer token for Koios (empty string = no auth).
fetchTxCbor :: Provider -> Network -> String -> String -> Aff String
fetchTxCbor provider network key txId =
  toAffE (fetchTxCborEffect provider network key txId)

resolveProducerTxContext :: Provider -> Network -> String -> String -> Aff String
resolveProducerTxContext provider network key inspectionResponse =
  toAffE
    ( resolveProducerTxContextImpl
        (resolutionProvider provider)
        (producerTxSource provider)
        inspectionResponse
        (\txId -> fetchTxCborEffect provider network key txId)
    )

fetchTxCborEffect :: Provider -> Network -> String -> String -> Effect (Promise String)
fetchTxCborEffect = case _ of
  Blockfrost -> Blockfrost.fetchTxCborEffect
  Koios      -> Koios.fetchTxCborEffect

resolutionProvider :: Provider -> String
resolutionProvider = case _ of
  Blockfrost -> "blockfrost"
  Koios      -> "koios"

producerTxSource :: Provider -> String
producerTxSource = case _ of
  Blockfrost -> "blockfrost.txs.cbor"
  Koios      -> "koios.tx_cbor"

foreign import resolveProducerTxContextImpl
  :: String -- provider
  -> String -- producer tx source
  -> String -- tx.inspect response
  -> (String -> Effect (Promise String)) -- fetchTxCbor by tx id
  -> Effect (Promise String)
