{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Conway.Inspector.ProtocolRegistry
Description : Pure embedded protocol-registry lookup and PlutusData adapter.
License     : Apache-2.0
-}
module Conway.Inspector.ProtocolRegistry
    ( enrichIntent
    ) where

import Cardano.Ledger.Api.Scripts.Data (Data, getPlutusData)
import Cardano.Ledger.Conway (ConwayEra)
import Control.Applicative ((<|>))
import Control.Monad (when, (<=<), (>=>))
import Data.Aeson ((.=))
import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Base16 qualified as Base16
import Data.Foldable qualified as Foldable
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust, mapMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import PlutusLedgerApi.V1 qualified as Plutus

import Conway.Inspector.EmbeddedRegistry (embeddedRegistryJson)

-- | Add annotations only to the successful tx.intent payload shape.
enrichIntent
    :: [Text]
    -> Map.Map Text Text
    -> Map.Map Text (Data ConwayEra)
    -> Aeson.Value
    -> Aeson.Value
enrichIntent referenceInputs inputScripts redeemers =
    modifyPath ["result", "intent"] enrich
  where
    registry = Aeson.decodeStrict' embeddedRegistryJson
    enrich intent@(Aeson.Object object) =
        case registry of
            Nothing -> intent
            Just value ->
                Aeson.Object $
                    modifyKey "value" (enrichValue value) $
                        modifyKey "scripts" (enrichScripts value) object
    enrich value = value
    enrichValue registryValue (Aeson.Object value) =
        Aeson.Object $
            modifyKey "outputs" (annotateOutputs registryValue) value
    enrichValue _ value = value
    enrichScripts registryValue (Aeson.Array scripts) =
        Aeson.Array
            (fmap (annotateScript registryValue inputScripts redeemers) scripts)
    enrichScripts _ value = value
    annotateOutputs registryValue (Aeson.Array outputs) =
        Aeson.Array
            (fmap (annotateOutput registryValue referenceInputs) outputs)
    annotateOutputs _ value = value

annotateOutput :: Aeson.Value -> [Text] -> Aeson.Value -> Aeson.Value
annotateOutput registry referenceInputs output@(Aeson.Object value) =
    fromMaybe output $ do
        hash <- outputHash value
        entry <- lookupEntry registry hash
        datum <- lookupObject "datum" value >>= lookupObject "decoded"
        annotation <-
            decodeDatum registry referenceInputs entry (Aeson.Object datum)
        pure (Aeson.Object (KeyMap.insert "decoded_datum" annotation value))
annotateOutput _ _ value = value

annotateScript
    :: Aeson.Value
    -> Map.Map Text Text
    -> Map.Map Text (Data ConwayEra)
    -> Aeson.Value
    -> Aeson.Value
annotateScript registry inputScripts redeemers script@(Aeson.Object value) =
    fromMaybe script $ do
        Aeson.String purpose <- KeyMap.lookup "purpose" value
        when (purpose /= "spending") Nothing
        Aeson.Object input <- KeyMap.lookup "input" value
        Aeson.String txId <- KeyMap.lookup "tx_id" input
        index <- KeyMap.lookup "index" input >>= asInteger
        entry <-
            Map.lookup (txId <> "#" <> Text.pack (show index)) inputScripts
                >>= lookupEntry registry
        raw <- Map.lookup (txId <> "#" <> Text.pack (show index)) redeemers
        annotation <- decodeRedeemer registry entry raw
        pure
            (Aeson.Object (KeyMap.insert "decoded_redeemer" annotation value))
annotateScript _ _ _ value = value

decodeDatum
    :: Aeson.Value
    -> [Text]
    -> Aeson.Object
    -> Aeson.Value
    -> Maybe Aeson.Value
decodeDatum registry referenceInputs entry raw = do
    schema <- lookupObject "datum_schema" entry
    decoded <- decodeSchema registry schema raw
    annotation registry referenceInputs entry "datum" schema decoded

decodeRedeemer
    :: Aeson.Value -> Aeson.Object -> Data ConwayEra -> Maybe Aeson.Value
decodeRedeemer registry entry raw = do
    blueprintValue <- blueprintFor registry entry
    validator <- lookupText "validator" entry
    rawValidators <- lookupArray "validators" blueprintValue
    rawValidator <-
        find
            ((== Just validator) . (lookupText "title" <=< asObject))
            (Foldable.toList rawValidators)
    rawRedeemer <- lookupObject "redeemer" =<< asObject rawValidator
    rawSchema <- lookupObject "schema" rawRedeemer
    decoded <-
        decodeSchema
            (Aeson.Object blueprintValue)
            rawSchema
            (plutusDataNode raw)
    annotation
        registry
        []
        entry
        "redeemer"
        rawSchema
        decoded

annotation
    :: Aeson.Value
    -> [Text]
    -> Aeson.Object
    -> Text
    -> Aeson.Object
    -> Aeson.Value
    -> Maybe Aeson.Value
annotation registry referenceInputs entry kind schema decoded = do
    protocol <- lookupText "blueprint" entry
    validator <- lookupText "validator" entry
    label <- lookupText "label" entry
    parameterized <- lookupBool "parameterized" entry
    let schemaRef =
            fromMaybe
                ("registry://" <> protocol <> "/" <> validator <> "/" <> kind)
                (lookupText "$ref" schema)
        parametersKnown = fromMaybe (not parameterized) (lookupBool "parameters_known" entry)
        (constructor, fields) = topLevel decoded
        base =
            [ "protocol" .= protocol
            , "version" .= blueprintVersion registry protocol
            , "validator" .= validator
            , "label" .= label
            , "parameterized" .= parameterized
            , "parameters_known" .= parametersKnown
            , "schema_ref" .= schemaRef
            , "constructor" .= constructor
            , "fields" .= fields
            ]
    pure $
        Aeson.object (base ++ deployment registry referenceInputs entry)

topLevel :: Aeson.Value -> (Text, Aeson.Value)
topLevel (Aeson.Object value) =
    ( fromMaybe "Constructor" (lookupText "name" value)
    , fromMaybe (Aeson.object []) (KeyMap.lookup "fields" value)
    )
topLevel _ = ("Data", Aeson.object [])

deployment
    :: Aeson.Value -> [Text] -> Aeson.Object -> [(Key.Key, Aeson.Value)]
deployment registry referenceInputs entry =
    case lookupText "labelled_by" entry >>= deploymentObject registry of
        Nothing -> []
        Just details ->
            [ "deployment"
                .= Aeson.Object
                    ( KeyMap.insert
                        "reference_input_matches"
                        ( Aeson.toJSON
                            (filter (`elem` deploymentOutrefs details) referenceInputs)
                        )
                        details
                    )
            ]

deploymentObject :: Aeson.Value -> Text -> Maybe Aeson.Object
deploymentObject registry labelledBy = do
    (path, selector) <- Text.breakOnEnd "#" <$> Just labelledBy
    files <- lookupObject "embedded_files" =<< asObject registry
    journal <- KeyMap.lookup (Key.fromText (Text.dropEnd 1 path)) files
    treasury <- lookupPath (Text.splitOn "." selector) journal
    owner <- lookupText "owner" =<< asObject treasury
    address <- lookupText "address" =<< asObject treasury
    script <- lookupObject "treasury_script" =<< asObject treasury
    deployedAt <- lookupText "deployed_at" script
    pure $
        KeyMap.fromList
            [ ("scope", Aeson.String selector)
            , ("owner", Aeson.String owner)
            , ("address", Aeson.String address)
            , ("script_role", Aeson.String "treasury_script")
            , ("deployed_at", Aeson.String deployedAt)
            ,
                ( "deployment_outrefs"
                , Aeson.toJSON (deploymentOutrefsFrom journal treasury)
                )
            ]

deploymentOutrefs :: Aeson.Object -> [Text]
deploymentOutrefs details =
    maybe
        []
        (mapMaybe asText . Foldable.toList)
        (lookupArray "deployment_outrefs" details)

deploymentOutrefsFrom :: Aeson.Value -> Aeson.Value -> [Text]
deploymentOutrefsFrom journal scope =
    mapMaybe (lookupText "deployed_at" <=< asObject) (descendants scope)
        ++ maybe [] pure (lookupText "scope_owners" =<< asObject journal)

descendants :: Aeson.Value -> [Aeson.Value]
descendants value@(Aeson.Object object) = value : concatMap descendants (KeyMap.elems object)
descendants (Aeson.Array values) = concatMap descendants (Foldable.toList values)
descendants _ = []

blueprintVersion :: Aeson.Value -> Text -> Text
blueprintVersion registry blueprintId =
    fromMaybe "" $ do
        blueprint <- blueprintForId registry blueprintId
        preamble <- lookupObject "preamble" blueprint
        lookupText "version" preamble

blueprintFor :: Aeson.Value -> Aeson.Object -> Maybe Aeson.Object
blueprintFor registry entry = lookupText "blueprint" entry >>= blueprintForId registry

blueprintForId :: Aeson.Value -> Text -> Maybe Aeson.Object
blueprintForId registry blueprintId = do
    root <- asObject registry
    blueprints <- lookupArray "blueprints" root
    entry <-
        find
            ((== Just blueprintId) . (lookupText "id" <=< asObject))
            (Foldable.toList blueprints)
    path <- lookupText "path" =<< asObject entry
    files <- lookupObject "embedded_files" root
    asObject =<< KeyMap.lookup (Key.fromText path) files

lookupEntry :: Aeson.Value -> Text -> Maybe Aeson.Object
lookupEntry registry hash = do
    root <- asObject registry
    direct <- lookupArray "validators" root
    instances <- lookupArray "instances" root
    asObject
        =<< find
            ((== Just hash) . (lookupText "on_chain_hash" <=< asObject))
            (Foldable.toList direct ++ Foldable.toList instances)

-- Schema adapter for both the registry's curated vocabulary and CIP-57.
decodeSchema
    :: Aeson.Value -> Aeson.Object -> Aeson.Value -> Maybe Aeson.Value
decodeSchema registry schema raw =
    case lookupText "$ref" schema of
        Just ref ->
            resolveReference registry ref >>= \resolved -> decodeSchema registry resolved raw
        Nothing -> case lookupArray "constructors" schema of
            Just constructors -> decodeAlternatives registry constructors raw
            Nothing -> case lookupArray "anyOf" schema of
                Just alternatives -> decodeAlternatives registry alternatives raw
                Nothing
                    | isJust (lookupInteger "index" schema) ->
                        decodeConstructor registry schema raw
                    | otherwise -> case lookupText "kind" schema <|> lookupText "dataType" schema of
                        Just "sum" ->
                            lookupArray "variants" schema >>= \variants -> decodeAlternatives registry variants raw
                        Just "constr" ->
                            lookupObject "of" schema >>= \inner -> decodeSchema registry inner raw
                        Just "constructor" -> decodeConstructor registry schema raw
                        Just "list" -> decodeList registry schema raw
                        Just "map" -> decodeMap registry schema raw
                        Just "int" -> integerNode raw
                        Just "integer" -> integerNode raw
                        Just "bytes" -> bytesNode raw
                        Just "data" -> Just (rawNode raw)
                        _ -> Just (rawNode raw)

decodeAlternatives
    :: Aeson.Value -> Aeson.Array -> Aeson.Value -> Maybe Aeson.Value
decodeAlternatives registry alternatives raw =
    findMap
        (asObject >=> \schema -> decodeSchema registry schema raw)
        (Foldable.toList alternatives)

decodeConstructor
    :: Aeson.Value -> Aeson.Object -> Aeson.Value -> Maybe Aeson.Value
decodeConstructor registry schema raw = do
    value <- asObject raw
    index <- lookupInteger "index" value
    expected <- lookupInteger "index" schema
    when (index /= expected) Nothing
    fields <- lookupArray "fields" value
    fieldSchemas <- lookupArray "fields" schema
    when (Foldable.length fields /= Foldable.length fieldSchemas) Nothing
    named <-
        sequence
            [ do
                fieldSchema <- asObject fieldSchemaValue
                name <-
                    lookupText "name" fieldSchema <|> lookupText "title" fieldSchema
                decoded <-
                    ( lookupObject "type" fieldSchema >>= \typ -> decodeSchema registry typ fieldValue
                        )
                        <|> decodeSchema registry fieldSchema fieldValue
                pure (Key.fromText name, decoded)
            | (fieldSchemaValue, fieldValue) <-
                zip (Foldable.toList fieldSchemas) (Foldable.toList fields)
            ]
    if length named /= length (Foldable.toList fields)
        then Nothing
        else
            Just $
                Aeson.object
                    [ "kind" .= ("constructor" :: Text)
                    , "name"
                        .= fromMaybe
                            ("Constructor" <> Text.pack (show index))
                            (lookupText "name" schema <|> lookupText "title" schema)
                    , "fields" .= Aeson.Object (KeyMap.fromList named)
                    ]

decodeList
    :: Aeson.Value -> Aeson.Object -> Aeson.Value -> Maybe Aeson.Value
decodeList registry schema raw = do
    values <- lookupArray "items" =<< asObject raw
    let schemas =
            maybe
                []
                Foldable.toList
                (lookupArray "fields" schema <|> lookupArray "slots" schema)
    items <- case lookupObject "element" schema of
        Just itemSchema ->
            traverse (decodeSchema registry itemSchema) (Foldable.toList values)
        Nothing
            | null schemas -> pure (map rawNode (Foldable.toList values))
            | otherwise ->
                sequence
                    [ asObject field >>= \fieldSchema -> decodeSchema registry fieldSchema value
                    | (field, value) <-
                        zip (Foldable.toList schemas) (Foldable.toList values)
                    ]
    Just $ Aeson.object ["kind" .= ("list" :: Text), "items" .= items]

decodeMap
    :: Aeson.Value -> Aeson.Object -> Aeson.Value -> Maybe Aeson.Value
decodeMap registry schema raw = do
    entries <- lookupArray "entries" =<< asObject raw
    let keySchema = lookupObject "keys" schema <|> lookupObject "key" schema
        valueSchema = lookupObject "values" schema <|> lookupObject "value" schema
    parsed <-
        traverse (decodeEntry keySchema valueSchema) (Foldable.toList entries)
    Just $ Aeson.object ["kind" .= ("map" :: Text), "entries" .= parsed]
  where
    decodeEntry keySchema valueSchema entry = do
        object <- asObject entry
        key <- KeyMap.lookup "key" object
        value <- KeyMap.lookup "value" object
        pure $
            Aeson.object
                [ "key"
                    .= maybe
                        (rawNode key)
                        ( \schema -> fromMaybe (rawNode key) (decodeSchema registry schema key)
                        )
                        keySchema
                , "value"
                    .= maybe
                        (rawNode value)
                        ( \schema -> fromMaybe (rawNode value) (decodeSchema registry schema value)
                        )
                        valueSchema
                ]

integerNode, bytesNode :: Aeson.Value -> Maybe Aeson.Value
integerNode value@(Aeson.Object object)
    | lookupText "kind" object == Just "int" =
        Just
            ( Aeson.object
                ["kind" .= ("integer" :: Text), "value" .= lookupText "value" object]
            )
integerNode _ = Nothing
bytesNode value@(Aeson.Object object)
    | lookupText "kind" object == Just "bytes" =
        Just
            ( Aeson.object
                ["kind" .= ("bytes" :: Text), "hex" .= lookupText "hex" object]
            )
bytesNode _ = Nothing

rawNode :: Aeson.Value -> Aeson.Value
rawNode value@(Aeson.Object object) = case lookupText "kind" object of
    Just "constr" ->
        Aeson.object
            [ "kind" .= ("constructor" :: Text)
            , "index" .= lookupInteger "index" object
            , "name"
                .= ( "Constructor"
                        <> Text.pack (show (fromMaybe 0 (lookupInteger "index" object)))
                   )
            , "fields"
                .= maybe
                    (Aeson.object [])
                    ( Aeson.Object
                        . KeyMap.fromList
                        . mapMaybe field
                        . zip [0 :: Int ..]
                        . Foldable.toList
                    )
                    (lookupArray "fields" object)
            ]
    Just "list" ->
        Aeson.object
            [ "kind" .= ("list" :: Text)
            , "items"
                .= maybe [] (map rawNode . Foldable.toList) (lookupArray "items" object)
            ]
    Just "map" ->
        Aeson.object
            [ "kind" .= ("map" :: Text)
            , "entries"
                .= maybe
                    []
                    (map rawEntry . Foldable.toList)
                    (lookupArray "entries" object)
            ]
    Just "int" -> fromMaybe value (integerNode value)
    Just "bytes" -> fromMaybe value (bytesNode value)
    _ -> value
  where
    field (ix, item) = Just (Key.fromText ("field" <> Text.pack (show ix)), rawNode item)
    rawEntry entry =
        maybe
            entry
            ( \o ->
                Aeson.object
                    [ "key" .= maybe Aeson.Null rawNode (KeyMap.lookup "key" o)
                    , "value" .= maybe Aeson.Null rawNode (KeyMap.lookup "value" o)
                    ]
            )
            (asObject entry)
rawNode value = value

resolveReference :: Aeson.Value -> Text -> Maybe Aeson.Object
resolveReference root ref = do
    pointer <- Text.stripPrefix "#/" ref
    resolved <-
        lookupPointer (map decodePointerToken (Text.splitOn "/" pointer)) root
    asObject resolved
  where
    lookupPointer [] value = Just value
    lookupPointer (key : keys) value =
        asObject value
            >>= KeyMap.lookup (Key.fromText key)
            >>= lookupPointer keys
    decodePointerToken = Text.replace "~1" "/" . Text.replace "~0" "~"

plutusDataNode :: Data ConwayEra -> Aeson.Value
plutusDataNode = rawPlutusDataNode . getPlutusData

rawPlutusDataNode :: Plutus.Data -> Aeson.Value
rawPlutusDataNode = \case
    Plutus.I integer ->
        Aeson.object
            ["kind" .= ("int" :: Text), "value" .= Text.pack (show integer)]
    Plutus.B bytes ->
        Aeson.object
            [ "kind" .= ("bytes" :: Text)
            , "hex" .= TextEncoding.decodeUtf8 (Base16.encode bytes)
            ]
    Plutus.List values ->
        Aeson.object
            ["kind" .= ("list" :: Text), "items" .= map rawPlutusDataNode values]
    Plutus.Map entries ->
        Aeson.object
            [ "kind" .= ("map" :: Text)
            , "entries"
                .= [ Aeson.object
                    [ "key" .= rawPlutusDataNode key
                    , "value" .= rawPlutusDataNode value
                    ]
                   | (key, value) <- entries
                   ]
            ]
    Plutus.Constr index fields ->
        Aeson.object
            [ "kind" .= ("constr" :: Text)
            , "index" .= index
            , "fields" .= map rawPlutusDataNode fields
            ]

modifyPath
    :: [Text] -> (Aeson.Value -> Aeson.Value) -> Aeson.Value -> Aeson.Value
modifyPath [] f value = f value
modifyPath (key : keys) f (Aeson.Object object) =
    Aeson.Object $
        case KeyMap.lookup (Key.fromText key) object of
            Nothing -> object
            Just value -> KeyMap.insert (Key.fromText key) (modifyPath keys f value) object
modifyPath _ _ value = value

modifyKey
    :: Key.Key
    -> (Aeson.Value -> Aeson.Value)
    -> Aeson.Object
    -> Aeson.Object
modifyKey key f object =
    case KeyMap.lookup key object of
        Nothing -> object
        Just value -> KeyMap.insert key (f value) object

asObject :: Aeson.Value -> Maybe Aeson.Object
asObject (Aeson.Object object) = Just object
asObject _ = Nothing
lookupObject key = asObject <=< KeyMap.lookup key
lookupArray key = asArray <=< KeyMap.lookup key
lookupText key = asText <=< KeyMap.lookup key
lookupBool key = asBool <=< KeyMap.lookup key
lookupInteger key = asInteger <=< KeyMap.lookup key
asArray (Aeson.Array value) = Just value
asArray _ = Nothing
asText (Aeson.String value) = Just value
asText _ = Nothing
asBool (Aeson.Bool value) = Just value
asBool _ = Nothing
asInteger :: Aeson.Value -> Maybe Integer
asInteger (Aeson.Number value) = Just (floor value)
asInteger _ = Nothing
lookupPath [] value = Just value
lookupPath (key : keys) value =
    asObject value
        >>= KeyMap.lookup (Key.fromText key)
        >>= lookupPath keys
outputHash :: Aeson.Object -> Maybe Text
outputHash value = do
    address <- lookupText "address_hex" value
    let credential = Text.take 56 (Text.drop 2 address)
    if Text.length credential == 56 then Just credential else Nothing
findMap :: (Foldable t) => (a -> Maybe b) -> t a -> Maybe b
findMap f = foldr (\value next -> f value <|> next) Nothing
