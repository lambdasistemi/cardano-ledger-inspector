module Provider
  ( Provider(..)
  , providerName
  , needsKey
  , credentialReady
  , readinessGuidance
  , providerFailureGuidance
  , focusProviderError
  , fetchTxCbor
  , resolveProducerTxContext
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.String as String
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

-- | The browser workflow requires the selected provider's credential before
-- any provider request. A Koios token permits an attempt but does not imply
-- that the deployed browser origin will pass Koios' CORS policy.
needsKey :: Provider -> Boolean
needsKey = case _ of
  Blockfrost -> true
  Koios      -> true

credentialReady :: Provider -> String -> Boolean
credentialReady provider credential =
  not (needsKey provider) || String.trim credential /= ""

readinessGuidance :: Provider -> String
readinessGuidance = case _ of
  Blockfrost ->
    "Blockfrost credential required: the provider is not ready. Add a project ID in Settings."
  Koios ->
    "Koios credential required: the provider is not ready. This deployed browser flow is CORS-blocked. Add a bearer token in Settings to satisfy the credential gate; a token does not remove this restriction."

providerFailureGuidance :: Provider -> String -> String
providerFailureGuidance provider =
  providerFailureGuidanceImpl (providerName provider)

focusProviderError :: Effect Unit
focusProviderError = focusProviderErrorImpl

-- | Unified fetch. `key` is the required project ID for Blockfrost or bearer
-- token for Koios; readiness is enforced before this boundary is called.
fetchTxCbor :: Provider -> Network -> String -> String -> Aff String
fetchTxCbor provider network key txId =
  toAffE (fetchTxCborEffect provider network key txId)

resolveProducerTxContext :: Provider -> Network -> String -> Boolean -> String -> Aff String
resolveProducerTxContext provider network key canFetchProducerTxs inspectionResponse =
  toAffE
    ( resolveProducerTxContextImpl
        (resolutionProvider provider)
        (producerTxSource provider)
        inspectionResponse
        (\txId -> fetchTxCborEffect provider network key txId)
        (fetchValidationContextEffect provider network key)
        canFetchProducerTxs
    )

fetchTxCborEffect :: Provider -> Network -> String -> String -> Effect (Promise String)
fetchTxCborEffect = case _ of
  Blockfrost -> Blockfrost.fetchTxCborEffect
  Koios      -> Koios.fetchTxCborEffect

fetchValidationContextEffect :: Provider -> Network -> String -> Effect (Promise String)
fetchValidationContextEffect provider network key =
  case provider of
    Blockfrost -> Blockfrost.fetchValidationContextEffect network key
    Koios -> Koios.fetchValidationContextEffect network key

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
  -> Effect (Promise String) -- fetch current validation context
  -> Boolean -- fetch producer tx CBOR
  -> Effect (Promise String)

foreign import providerFailureGuidanceImpl :: String -> String -> String

foreign import focusProviderErrorImpl :: Effect Unit
