{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosis.Conway
    ( DecodedTx (..)
    , decodeTxFromCborHex
    , extractDatumHashes
    ) where

import qualified Codec.CBOR.Read as CBOR
import qualified Codec.CBOR.Term as Term
import Data.Bifunctor (first)
import Data.Bits (shiftR, (.&.))
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Lazy as BSL
import Data.List (foldl')
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Data.Word (Word8)

import TxDeepDiagnosis.Types

data DecodedTx = DecodedTx
    { txInputs :: ![OutRef]
    , txCollateralInputs :: ![OutRef]
    , txReferenceInputs :: ![OutRef]
    , txOutputs :: ![Output]
    , txCollateralReturn :: !(Maybe Output)
    , txTotalCollateral :: !(Maybe Lovelace)
    , txFee :: !Lovelace
    , txTtl :: !(Maybe Integer)
    , txWithdrawals :: ![(Credential, Lovelace)]
    , txRequiredSigners :: ![Hash28]
    , txMint :: ![(Hash28, Map ByteString Integer)]
    , txAuxiliaryDataHash :: !(Maybe Hash32)
    , txScriptDataHash :: !(Maybe Hash32)
    , txAuxiliaryData :: !(Maybe Term.Term)
    , txWitnessSet :: !(Maybe Term.Term)
    , txValidityFlag :: !(Maybe Bool)
    , txRawSize :: !Int
    , txRawHex :: !Text
    }
    deriving (Show)

decodeTxFromCborHex :: Text -> Either String DecodedTx
decodeTxFromCborHex hex = do
    bs <- first show $ B16.decode (TE.encodeUtf8 (Text.strip hex))
    decodeTxFromCborBytes bs hex

decodeTxFromCborBytes :: ByteString -> Text -> Either String DecodedTx
decodeTxFromCborBytes bs hex = do
    (_, term) <- first show $ CBOR.deserialiseFromBytes Term.decodeTerm (BSL.fromStrict bs)
    case asList term of
        Just (body : rest) -> do
            let (witnesses, validity, aux) = case rest of
                    [w] -> (Just w, Nothing, Nothing)
                    [w, v] -> (Just w, Just v, Nothing)
                    [w, v, a] -> (Just w, Just v, Just a)
                    _ -> (Nothing, Nothing, Nothing)
            buildTx body witnesses validity aux bs hex
        _ -> Left "outer envelope is not a list of >=1 element"

buildTx
    :: Term.Term
    -> Maybe Term.Term
    -> Maybe Term.Term
    -> Maybe Term.Term
    -> ByteString
    -> Text
    -> Either String DecodedTx
buildTx body witnesses validity aux raw hex = do
    bodyMap <- termAsMap body
    let lookupK k = lookup (Term.TInt k) bodyMap
    inputsT <- mustField 0 lookupK
    inputs <- mapM termAsOutRef =<< termAsArray inputsT
    outputsT <- mustField 1 lookupK
    outputs <- mapM decodeOutput =<< termAsArray outputsT
    fee <- termAsInteger =<< mustField 2 lookupK
    let ttl = case lookupK 3 of
            Just t -> rightToMaybe (termAsInteger t)
            Nothing -> Nothing
    let withdrawals = case lookupK 5 of
            Just (Term.TMap entries) -> mapMaybe parseWithdrawal entries
            Just (Term.TMapI entries) -> mapMaybe parseWithdrawal entries
            _ -> []
    let auxHash = case lookupK 7 of
            Just (Term.TBytes b) -> Just b
            _ -> Nothing
    let scriptHash = case lookupK 11 of
            Just (Term.TBytes b) -> Just b
            _ -> Nothing
    collateralInputs <- case lookupK 13 of
        Just t -> mapM termAsOutRef =<< termAsArray t
        Nothing -> pure []
    let requiredSigners = case lookupK 14 of
            Just t -> case termAsArray t of
                Right xs -> [b | Term.TBytes b <- xs]
                _ -> []
            Nothing -> []
    let collReturn = case lookupK 16 of
            Just t -> rightToMaybe (decodeOutput t)
            Nothing -> Nothing
    let totalColl = case lookupK 17 of
            Just t -> rightToMaybe (termAsInteger t)
            Nothing -> Nothing
    referenceInputs <- case lookupK 18 of
        Just t -> mapM termAsOutRef =<< termAsArray t
        Nothing -> pure []
    let mint = case lookupK 9 of
            Just (Term.TMap entries) -> mapMaybe parseMintEntry entries
            Just (Term.TMapI entries) -> mapMaybe parseMintEntry entries
            _ -> []
    let validityFlag = case validity of
            Just (Term.TBool b) -> Just b
            _ -> Nothing
    pure DecodedTx
        { txInputs = inputs
        , txCollateralInputs = collateralInputs
        , txReferenceInputs = referenceInputs
        , txOutputs = outputs
        , txCollateralReturn = collReturn
        , txTotalCollateral = totalColl
        , txFee = fee
        , txTtl = ttl
        , txWithdrawals = withdrawals
        , txRequiredSigners = requiredSigners
        , txMint = mint
        , txAuxiliaryDataHash = auxHash
        , txScriptDataHash = scriptHash
        , txAuxiliaryData = aux
        , txWitnessSet = witnesses
        , txValidityFlag = validityFlag
        , txRawSize = BS.length raw
        , txRawHex = hex
        }

rightToMaybe :: Either e a -> Maybe a
rightToMaybe (Right a) = Just a
rightToMaybe (Left _) = Nothing

mustField :: Int -> (Int -> Maybe Term.Term) -> Either String Term.Term
mustField k l = case l k of
    Just t -> Right t
    Nothing -> Left ("missing tx body key " <> show k)

asList :: Term.Term -> Maybe [Term.Term]
asList (Term.TList xs) = Just xs
asList (Term.TListI xs) = Just xs
asList _ = Nothing

termAsMap :: Term.Term -> Either String [(Term.Term, Term.Term)]
termAsMap (Term.TMap xs) = Right xs
termAsMap (Term.TMapI xs) = Right xs
termAsMap _ = Left "expected map"

termAsArray :: Term.Term -> Either String [Term.Term]
termAsArray (Term.TList xs) = Right xs
termAsArray (Term.TListI xs) = Right xs
termAsArray (Term.TTagged _ inner) = termAsArray inner
termAsArray _ = Left "expected array (or tagged set)"

termAsInteger :: Term.Term -> Either String Integer
termAsInteger (Term.TInt n) = Right (fromIntegral n)
termAsInteger (Term.TInteger n) = Right n
termAsInteger _ = Left "expected integer"

termAsOutRef :: Term.Term -> Either String OutRef
termAsOutRef t = case asList t of
    Just [Term.TBytes h, ix] -> OutRef h . fromIntegral <$> termAsInteger ix
    _ -> Left "expected outref [tx_hash, ix]"

parseWithdrawal :: (Term.Term, Term.Term) -> Maybe (Credential, Lovelace)
parseWithdrawal (Term.TBytes addr, v) = do
    cred <- decodeRewardAddress addr
    case termAsInteger v of
        Right l -> Just (cred, l)
        _ -> Nothing
parseWithdrawal _ = Nothing

decodeRewardAddress :: ByteString -> Maybe Credential
decodeRewardAddress bs
    | BS.length bs /= 29 = Nothing
    | otherwise =
        let header = BS.head bs
            payload = BS.drop 1 bs
            scriptStake = (header .&. 0x10) /= 0
        in Just $ if scriptStake then ScriptCred payload else KeyCred payload

parseMintEntry :: (Term.Term, Term.Term) -> Maybe (Hash28, Map ByteString Integer)
parseMintEntry (Term.TBytes pol, Term.TMap entries) =
    Just (pol, Map.fromList [(an, n) | (Term.TBytes an, v) <- entries
                                     , Right n <- [termAsInteger v]])
parseMintEntry (Term.TBytes pol, Term.TMapI entries) =
    Just (pol, Map.fromList [(an, n) | (Term.TBytes an, v) <- entries
                                     , Right n <- [termAsInteger v]])
parseMintEntry _ = Nothing

decodeOutput :: Term.Term -> Either String Output
decodeOutput t = case t of
    Term.TMap entries -> babbageOutput entries
    Term.TMapI entries -> babbageOutput entries
    Term.TList xs -> alonzoOutput xs
    Term.TListI xs -> alonzoOutput xs
    _ -> Left "expected output (map or list)"

babbageOutput :: [(Term.Term, Term.Term)] -> Either String Output
babbageOutput entries = do
    addrT <- maybe (Left "output missing address") Right $ lookup (Term.TInt 0) entries
    addr <- case addrT of
        Term.TBytes b -> decodeAddress b
        _ -> Left "address not bytes"
    valT <- maybe (Left "output missing value") Right $ lookup (Term.TInt 1) entries
    val <- decodeValue valT
    let datum = case lookup (Term.TInt 2) entries of
            Just inner -> case asList inner of
                Just [Term.TInt 0, Term.TBytes h] -> DatumHash h
                Just [Term.TInt 1, Term.TTagged 24 (Term.TBytes b)] -> InlineDatum b
                _ -> NoDatum
            Nothing -> NoDatum
    let scriptRef = case lookup (Term.TInt 3) entries of
            Just (Term.TTagged 24 (Term.TBytes b))
                | BS.length b >= 28 -> Just (BS.take 28 b)
            _ -> Nothing
    pure Output
        { outAddress = addr
        , outValue = val
        , outDatum = datum
        , outScriptRefHash = scriptRef
        }

alonzoOutput :: [Term.Term] -> Either String Output
alonzoOutput xs = case xs of
    [Term.TBytes addrB, valT] -> do
        addr <- decodeAddress addrB
        val <- decodeValue valT
        pure Output { outAddress = addr, outValue = val, outDatum = NoDatum, outScriptRefHash = Nothing }
    [Term.TBytes addrB, valT, Term.TBytes h] -> do
        addr <- decodeAddress addrB
        val <- decodeValue valT
        pure Output { outAddress = addr, outValue = val, outDatum = DatumHash h, outScriptRefHash = Nothing }
    _ -> Left "alonzo output: expected [addr, value] or [addr, value, datum_hash]"

decodeValue :: Term.Term -> Either String Value
decodeValue (Term.TInt n) = Right (adaOnly (fromIntegral n))
decodeValue (Term.TInteger n) = Right (adaOnly n)
decodeValue t = case asList t of
    Just [coinT, multi] -> do
        coin <- termAsInteger coinT
        policies <- termAsMap multi
        let assets = Map.fromList
                [ (Asset polB anB, n)
                | (Term.TBytes polB, inner) <- policies
                , Right inner' <- [termAsMap inner]
                , (Term.TBytes anB, vT) <- inner'
                , Right n <- [termAsInteger vT]
                ]
        pure (Value coin assets)
    _ -> Left "value: expected uint or [coin, multiasset]"

decodeAddress :: ByteString -> Either String Address
decodeAddress bs
    | BS.null bs = Left "empty address"
    | otherwise =
        let header = BS.head bs
            payload = BS.drop 1 bs
            ty = (header `shiftR` 4) .&. 0x0F
        in case ty of
            8 -> Right Address { addrPayment = KeyCred BS.empty, addrStake = Nothing, addrIsBootstrap = True }
            t | t < 8 -> decodeShelleyAddress t payload
              | otherwise -> Left ("unknown address type " <> show t)

decodeShelleyAddress :: Word8 -> ByteString -> Either String Address
decodeShelleyAddress ty payload =
    case ty of
        0 -> mk2 KeyCred (Just . KeyCred)
        1 -> mk2 ScriptCred (Just . KeyCred)
        2 -> mk2 KeyCred (Just . ScriptCred)
        3 -> mk2 ScriptCred (Just . ScriptCred)
        4 -> mk1WithPointer KeyCred
        5 -> mk1WithPointer ScriptCred
        6 -> mk1 KeyCred
        7 -> mk1 ScriptCred
        _ -> Left ("non-shelley type " <> show ty)
  where
    mk2 mkP mkS
        | BS.length payload == 56 =
            Right Address { addrPayment = mkP (BS.take 28 payload), addrStake = mkS (BS.drop 28 payload), addrIsBootstrap = False }
        | otherwise = Left "shelley addr type 0-3: payload not 56 bytes"
    mk1 mkP
        | BS.length payload == 28 =
            Right Address { addrPayment = mkP payload, addrStake = Nothing, addrIsBootstrap = False }
        | otherwise = Left "shelley addr type 6/7: payload not 28 bytes"
    mk1WithPointer mkP
        | BS.length payload >= 28 =
            Right Address { addrPayment = mkP (BS.take 28 payload), addrStake = Nothing, addrIsBootstrap = False }
        | otherwise = Left "shelley addr type 4/5: payload too short"

extractDatumHashes :: ByteString -> [Hash28]
extractDatumHashes bs =
    case CBOR.deserialiseFromBytes Term.decodeTerm (BSL.fromStrict bs) of
        Left _ -> []
        Right (_, t) -> walk t []
  where
    walk (Term.TBytes b) acc
        | BS.length b == 28 = b : acc
        | otherwise = acc
    walk (Term.TList xs) acc = foldl' (flip walk) acc xs
    walk (Term.TListI xs) acc = foldl' (flip walk) acc xs
    walk (Term.TMap xs) acc = foldl' (flip walk) acc (concatMap pairList xs)
    walk (Term.TMapI xs) acc = foldl' (flip walk) acc (concatMap pairList xs)
    walk (Term.TTagged _ inner) acc = walk inner acc
    walk _ acc = acc
    pairList (a, b) = [a, b]
