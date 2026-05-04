{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : TxDeepDiagnosisHost.Render.Names
Description : Hash → human label resolution against the protocol registry.

Every node in the explain artifacts that comes from a hash (script
hash, payment-credential hash, signer hash) flows through 'resolveScript'
or 'resolveAddress'. Unknown hashes are truncated rather than guessed so
the rendered output stays honest.
-}
module TxDeepDiagnosisHost.Render.Names
    ( PartyName (..)
    , PartySource (..)
    , resolveScript
    , resolveAddress
    , paymentScriptHash
    , truncateHash
    ) where

import Data.Text (Text)
import qualified Data.Text as Text

import TxDeepDiagnosisHost.Registry
    ( AmaruScope (..)
    , Identification (..)
    , ProtocolRegistry
    , RegistryInstance (..)
    , RegistryValidator (..)
    , findScopeByOwner
    , identifyByHash
    , prAmaru
    )

{- | Origin of a resolved label. Preserved so renderers can style or
caveat labels by source.
-}
data PartySource
    = -- | matched a known validator hash
      FromValidator
    | -- | matched a known instance hash (label disambiguated by hash tail)
      FromInstance
    | -- | matched an Amaru treasury role
      FromAmaruRole
    | -- | matched the owner-key hash of an Amaru scope
      FromAmaruOwner
    | -- | no registry hit; label is truncated hex
      TruncatedHex
    deriving (Show, Eq)

-- | A registry-resolved or truncated party label.
data PartyName = PartyName
    { pnLabel :: !Text
    , pnSource :: !PartySource
    }
    deriving (Show, Eq)

{- | Resolve a script (or any 28-byte) hash hex against the registry.
Validator hits return their plain label. Instance hits append the last
six hex of the hash so distinct instances of the same template stay
distinguishable. Misses fall back to truncated hex.
-}
resolveScript :: ProtocolRegistry -> Text -> PartyName
resolveScript reg h = case identifyByHash reg h of
    IdValidator v ->
        PartyName
            { pnLabel = labelFromValidator v
            , pnSource = FromValidator
            }
    IdInstance inst _scope ->
        PartyName
            { pnLabel = riLabel inst <> " (" <> hashTail h <> ")"
            , pnSource = FromInstance
            }
    IdAmaruRole scope role ->
        PartyName
            { pnLabel = ascName scope <> " " <> role
            , pnSource = FromAmaruRole
            }
    IdUnknown -> PartyName{pnLabel = truncateHash h, pnSource = TruncatedHex}

{- | The validator's own @label@ field, falling back to the validator
name if the registry author left @label@ unset.
-}
labelFromValidator :: RegistryValidator -> Text
labelFromValidator v = case rvLabel v of
    Just l -> l
    Nothing -> rvValidator v

{- | Resolve a Cardano address-hex (the lowercase concatenation of
header + payment credential + optional stake credential) against the
registry. Script-credential addresses are looked up via 'resolveScript'
on the payment script hash. Key-credential addresses fall through to a
truncated label unless the payment-key hash matches an Amaru scope
owner.
-}
resolveAddress :: ProtocolRegistry -> Text -> PartyName
resolveAddress reg addrHex
    | Text.length addrHex < 2 =
        PartyName{pnLabel = truncateHash addrHex, pnSource = TruncatedHex}
    | otherwise =
        let header = Text.take 2 addrHex
            paymentHex = Text.take 56 (Text.drop 2 addrHex)
            isScriptPayment = headerHasScriptPayment header
        in  if isScriptPayment
                then resolveScript reg paymentHex
                else case prAmaru reg >>= \j -> findScopeByOwner j paymentHex of
                    Just scope ->
                        PartyName
                            { pnLabel = ascName scope <> " owner"
                            , pnSource = FromAmaruOwner
                            }
                    Nothing ->
                        PartyName
                            { pnLabel = "key " <> hashTail paymentHex
                            , pnSource = TruncatedHex
                            }

{- | Extract the payment script hash from an address-hex when the
header indicates a script payment credential. Returns 'Nothing' when
the payment is key-credential or the address is too short.
-}
paymentScriptHash :: Text -> Maybe Text
paymentScriptHash addrHex
    | Text.length addrHex < 58 = Nothing
    | otherwise =
        let header = Text.take 2 addrHex
        in  if headerHasScriptPayment header
                then Just (Text.take 56 (Text.drop 2 addrHex))
                else Nothing

{- | The header byte of a Shelley address encodes the type in the high
nibble. Bits 0x40 and 0x10 of that nibble select script payment
credentials (types 0x10, 0x30, 0x50, 0x70 — the high-nibble values
01, 03, 05, 07). Reading the header as a hex pair, the script-payment
header values are exactly those whose first hex digit is in
{1,3,5,7}. Any non-hex header is treated as key-credential.
-}
headerHasScriptPayment :: Text -> Bool
headerHasScriptPayment header = case Text.unpack (Text.toLower header) of
    (c : _) -> c `elem` ("1357" :: String)
    _ -> False

{- | Truncate a hex string to the form @first8…last8@ for display when
no registry label is available.
-}
truncateHash :: Text -> Text
truncateHash h
    | Text.length h <= 18 = h
    | otherwise = Text.take 8 h <> "…" <> Text.takeEnd 8 h

-- | Last 6 hex characters of a hash, used to disambiguate instance labels.
hashTail :: Text -> Text
hashTail h
    | Text.length h <= 6 = h
    | otherwise = Text.takeEnd 6 h
