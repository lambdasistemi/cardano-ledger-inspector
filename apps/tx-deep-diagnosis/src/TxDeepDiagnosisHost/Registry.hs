{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosisHost.Registry
    ( ProtocolRegistry (..)
    , RegistryValidator (..)
    , RegistryInstance (..)
    , AmaruScope (..)
    , AmaruScript (..)
    , AmaruJournal (..)
    , DatumSchema (..)
    , SchemaSource (..)
    , AikenSource (..)
    , SchemaConstructor (..)
    , SchemaField (..)
    , FieldType (..)
    , TupleField (..)
    , aikenSourceUrl
    , loadRegistry
    , loadRegistries
    , identifyByHash
    , datumSchemaForHash
    , findScopeByOwner
    , findScopeByRefOutref
    , Identification (..)
    ) where

import Data.Aeson
    ( FromJSON (..)
    , eitherDecodeFileStrict
    , withObject
    , (.!=)
    , (.:)
    , (.:?)
    )
import qualified Data.Aeson as A
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Aeson.Types as A
import Data.List (find)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory (doesFileExist)
import System.FilePath ((</>))

data RegistryValidator = RegistryValidator
    { rvHashHex :: !Text
    , rvBlueprint :: !Text
    , rvValidator :: !Text
    , rvParameterized :: !Bool
    , rvLabel :: !(Maybe Text)
    , rvDatumSchema :: !(Maybe DatumSchema)
    -- ^ Optional typed datum schema for this validator. When
    -- present, the renderer can interpret the inline datum AST as
    -- named record fields. Absent by default; vendoring is per
    -- contract and carries explicit provenance via 'SchemaSource'.
    }
    deriving (Show)

data RegistryInstance = RegistryInstance
    { riHashHex :: !Text
    , riBlueprint :: !Text
    , riValidator :: !Text
    , riParameterized :: !Bool
    , riParametersKnown :: !Bool
    , riLabel :: !Text
    , riLabelledBy :: !(Maybe Text)
    , riDatumSchema :: !(Maybe DatumSchema)
    -- ^ See 'rvDatumSchema'.
    }
    deriving (Show)

{- | Typed datum schema for a contract. The schema is consulted by
the explain renderer to translate the inline datum's Plutus Data
AST into named record fields, with the 'SchemaSource' surfaced as a
mandatory provenance disclaimer.
-}
data DatumSchema = DatumSchema
    { dsSource :: !SchemaSource
    , dsName :: !Text
    -- ^ Top-level type name, e.g. @\"OrderDatum\"@.
    , dsConstructors :: ![SchemaConstructor]
    -- ^ Sum-of-product constructors. Index matches the Plutus
    -- Data 'Constr' tag.
    }
    deriving (Show)

{- | Where the schema came from. The renderer always emits a
provenance line before any typed body so a reviewer can decide
whether to trust the field names.
-}
data SchemaSource
    = -- | Carried in the contract author's CIP-57 plutus.json blueprint.
      SourcePlutusJson
    | -- | Hand-curated from an Aiken source file at a pinned commit.
      -- Field names must match the source for the disclaimer to be
      -- accurate.
      SourceAiken !AikenSource
    | -- | Reverse-engineered with no upstream typed source. Use
      -- sparingly; the disclaimer makes this status explicit.
      SourceManual !Text
    deriving (Show)

data AikenSource = AikenSource
    { asRepo :: !Text
    -- ^ @owner/repo@ pair, e.g. @SundaeSwap-finance/sundae-contracts@.
    , asCommit :: !Text
    -- ^ Pinned commit SHA. Required so the disclaimer URL never drifts.
    , asPath :: !Text
    -- ^ Path within the repo, e.g. @validators/order.ak@.
    , asLineStart :: !(Maybe Int)
    , asLineEnd :: !(Maybe Int)
    , asNote :: !(Maybe Text)
    -- ^ Optional one-line annotation (e.g. \"reorganised in PR \#42\").
    }
    deriving (Show)

data SchemaConstructor = SchemaConstructor
    { scIndex :: !Integer
    , scName :: !Text
    , scFields :: ![SchemaField]
    }
    deriving (Show)

data SchemaField = SchemaField
    { sfName :: !Text
    , sfType :: !FieldType
    }
    deriving (Show)

{- | Field types supported by the schema. 'FtData' is the escape
hatch — when a field is left as raw 'Data' (e.g. @extensions@ in
SundaeSwap V3) the renderer falls back to the untyped pretty-printer
so the bytes are still visible.
-}
data FieldType
    = -- | optional semantic hint, e.g. @\"PolicyId\"@.
      FtBytes !(Maybe Text)
    | -- | optional semantic hint, e.g. @\"Lovelace\"@.
      FtInt !(Maybe Text)
    | FtList !FieldType
    | -- | heterogeneous tuple, encoded on-chain as a Plutus list.
      -- Aiken @(a, b, c)@ values land here; the per-position name
      -- carried in 'TupleField' lets the renderer label each slot.
      FtTuple ![TupleField]
    | -- | single-record nesting (Plutus @Constr 0@ wrapping)
      FtConstr !SchemaConstructor
    | -- | tagged union; matched by Constr tag at decode time
      FtSum ![SchemaConstructor]
    | FtData
    deriving (Show)

-- | A name-and-type slot inside an 'FtTuple'.
data TupleField = TupleField
    { tfName :: !Text
    , tfType :: !FieldType
    }
    deriving (Show)

{- | Build a clickable GitHub URL pointing at the cited Aiken source
range. Used by the renderer's provenance line.
-}
aikenSourceUrl :: AikenSource -> Text
aikenSourceUrl src =
    "https://github.com/"
        <> asRepo src
        <> "/blob/"
        <> asCommit src
        <> "/"
        <> asPath src
        <> case (asLineStart src, asLineEnd src) of
            (Just a, Just b) -> "#L" <> Text.pack (show a) <> "-L" <> Text.pack (show b)
            (Just a, Nothing) -> "#L" <> Text.pack (show a)
            _ -> ""

data ProtocolRegistry = ProtocolRegistry
    { prValidators :: ![RegistryValidator]
    , prInstances :: ![RegistryInstance]
    , prAmaru :: !(Maybe AmaruJournal)
    }
    deriving (Show)

instance FromJSON RegistryValidator where
    parseJSON = withObject "RegistryValidator" $ \o ->
        RegistryValidator
            <$> o .: "on_chain_hash"
            <*> o .: "blueprint"
            <*> o .: "validator"
            <*> o .:? "parameterized" .!= False
            <*> o .:? "label"
            <*> o .:? "datum_schema"

instance FromJSON RegistryInstance where
    parseJSON = withObject "RegistryInstance" $ \o ->
        RegistryInstance
            <$> o .: "on_chain_hash"
            <*> o .: "blueprint"
            <*> o .: "validator"
            <*> o .:? "parameterized" .!= True
            <*> o .:? "parameters_known" .!= False
            <*> o .: "label"
            <*> o .:? "labelled_by"
            <*> o .:? "datum_schema"

instance FromJSON DatumSchema where
    parseJSON = withObject "DatumSchema" $ \o ->
        DatumSchema
            <$> o .: "source"
            <*> o .: "name"
            <*> o .: "constructors"

instance FromJSON SchemaSource where
    parseJSON = withObject "SchemaSource" $ \o -> do
        kind <- o .: "kind" :: A.Parser Text
        case kind of
            "plutus_json" -> pure SourcePlutusJson
            "aiken" -> SourceAiken <$> parseJSON (A.Object o)
            "manual" -> SourceManual <$> o .: "note"
            other -> fail ("unknown schema source kind: " <> Text.unpack other)

instance FromJSON AikenSource where
    parseJSON = withObject "AikenSource" $ \o ->
        AikenSource
            <$> o .: "repo"
            <*> o .: "commit"
            <*> o .: "path"
            <*> o .:? "line_start"
            <*> o .:? "line_end"
            <*> o .:? "note"

instance FromJSON SchemaConstructor where
    parseJSON = withObject "SchemaConstructor" $ \o ->
        SchemaConstructor
            <$> o .: "index"
            <*> o .: "name"
            <*> o .:? "fields" .!= []

instance FromJSON SchemaField where
    parseJSON = withObject "SchemaField" $ \o ->
        SchemaField
            <$> o .: "name"
            <*> o .: "type"

instance FromJSON FieldType where
    parseJSON = withObject "FieldType" $ \o -> do
        kind <- o .: "kind" :: A.Parser Text
        case kind of
            "bytes" -> FtBytes <$> o .:? "semantic"
            "int" -> FtInt <$> o .:? "semantic"
            "list" -> FtList <$> o .: "element"
            "tuple" -> FtTuple <$> o .: "slots"
            "constr" -> FtConstr <$> o .: "of"
            "sum" -> FtSum <$> o .: "variants"
            "data" -> pure FtData
            other -> fail ("unknown field type kind: " <> Text.unpack other)

instance FromJSON TupleField where
    parseJSON = withObject "TupleField" $ \o ->
        TupleField
            <$> o .: "name"
            <*> o .: "type"

data RegistryFile = RegistryFile
    { rfValidators :: ![RegistryValidator]
    , rfInstances :: ![RegistryInstance]
    }

instance FromJSON RegistryFile where
    parseJSON = withObject "Registry" $ \o ->
        RegistryFile
            <$> o .:? "validators" .!= []
            <*> o .:? "instances" .!= []

data AmaruScript = AmaruScript
    { asHash :: !Text
    , asDeployedAt :: !Text
    }
    deriving (Show)

instance FromJSON AmaruScript where
    parseJSON = withObject "AmaruScript" $ \o ->
        AmaruScript <$> o .: "hash" <*> o .: "deployed_at"

data AmaruScope = AmaruScope
    { ascName :: !Text
    , ascOwner :: !(Maybe Text)
    , ascBudget :: !(Maybe Integer)
    , ascAddress :: !Text
    , ascTreasuryScript :: !AmaruScript
    , ascPermissionsScript :: !AmaruScript
    , ascRegistryScript :: !AmaruScript
    }
    deriving (Show)

data AmaruJournal = AmaruJournal
    { ajScopeOwners :: !Text
    , ajScopes :: ![AmaruScope]
    }
    deriving (Show)

instance FromJSON AmaruJournal where
    parseJSON = withObject "AmaruJournal" $ \o -> do
        owners <- o .: "scope_owners"
        treasuriesObj <- o .: "treasuries"
        let scopes = mapMaybe parseScope (KeyMap.toList treasuriesObj)
        pure AmaruJournal{ajScopeOwners = owners, ajScopes = scopes}
      where
        parseScope (k, v) =
            let name = Key.toText k
            in  case A.parseEither (parseScopeBody name) v of
                    Right s -> Just s
                    Left _ -> Nothing
        parseScopeBody name = withObject "Scope" $ \so ->
            AmaruScope name
                <$> so .:? "owner"
                <*> so .:? "budget"
                <*> so .: "address"
                <*> so .: "treasury_script"
                <*> so .: "permissions_script"
                <*> so .: "registry_script"

-- Load a single registry root. Use 'loadRegistries' to layer multiple
-- (e.g. the bundled registry plus user-supplied overlays).
loadRegistry :: FilePath -> IO ProtocolRegistry
loadRegistry root = do
    let registryPath = root </> "registry.json"
        amaruPath = root </> "amaru-treasury" </> "journal-2026.json"
    rf <- do
        exists <- doesFileExist registryPath
        if exists
            then
                either (\e -> error ("registry.json decode: " <> e)) id
                    <$> eitherDecodeFileStrict registryPath
            else pure (RegistryFile [] [])
    aj <- do
        exists <- doesFileExist amaruPath
        if exists
            then either (const Nothing) Just <$> eitherDecodeFileStrict amaruPath
            else pure Nothing
    pure
        ProtocolRegistry
            { prValidators = rfValidators rf
            , prInstances = rfInstances rf
            , prAmaru = aj
            }

-- Layer multiple registry roots into one. Validator and instance lists
-- are concatenated (later entries shadow earlier ones at lookup time
-- via 'find'); the Amaru journal is last-wins since it is keyed once
-- per project. Roots are processed in left-to-right order, so the
-- canonical call site is `loadRegistries [bundled, userExtra1, ...]`.
loadRegistries :: [FilePath] -> IO ProtocolRegistry
loadRegistries roots = do
    rs <- mapM loadRegistry roots
    pure
        ProtocolRegistry
            { prValidators = concatMap prValidators rs
            , prInstances = concatMap prInstances rs
            , prAmaru = lastJust (map prAmaru rs)
            }
  where
    lastJust = foldr (\x acc -> case x of Just _ -> x; Nothing -> acc) Nothing

-- \^ folds RIGHT-to-left, so the LAST Just wins (= the rightmost
-- registry root with an Amaru journal overrides any earlier one).

data Identification
    = IdValidator !RegistryValidator
    | IdInstance !RegistryInstance !(Maybe AmaruScope)
    | IdAmaruRole !AmaruScope !Text
    | IdUnknown
    deriving (Show)

{- | Find a 'DatumSchema' for a given script hash. Validators take
precedence over instances when both have a schema, mirroring the
priority used by 'identifyByHash'.
-}
datumSchemaForHash :: ProtocolRegistry -> Text -> Maybe DatumSchema
datumSchemaForHash reg hh =
    case find ((== hh) . rvHashHex) (prValidators reg) of
        Just v | Just ds <- rvDatumSchema v -> Just ds
        _ -> case find ((== hh) . riHashHex) (prInstances reg) of
            Just inst | Just ds <- riDatumSchema inst -> Just ds
            _ -> Nothing

identifyByHash :: ProtocolRegistry -> Text -> Identification
identifyByHash reg hh =
    case find ((== hh) . rvHashHex) (prValidators reg) of
        Just v -> IdValidator v
        Nothing -> case find ((== hh) . riHashHex) (prInstances reg) of
            Just inst ->
                let scope = case prAmaru reg of
                        Just j -> findAmaruScopeByTreasury j hh
                        Nothing -> Nothing
                in  IdInstance inst scope
            Nothing -> case prAmaru reg of
                Just j -> case findAmaruRole j hh of
                    Just (s, role) -> IdAmaruRole s role
                    Nothing -> IdUnknown
                Nothing -> IdUnknown

findAmaruScopeByTreasury :: AmaruJournal -> Text -> Maybe AmaruScope
findAmaruScopeByTreasury j hh = find (\s -> asHash (ascTreasuryScript s) == hh) (ajScopes j)

findAmaruRole :: AmaruJournal -> Text -> Maybe (AmaruScope, Text)
findAmaruRole j hh =
    let check s
            | asHash (ascTreasuryScript s) == hh = Just (s, "treasury")
            | asHash (ascPermissionsScript s) == hh = Just (s, "permissions")
            | asHash (ascRegistryScript s) == hh = Just (s, "registry")
            | otherwise = Nothing
    in  case mapMaybe check (ajScopes j) of
            (m : _) -> Just m
            [] -> Nothing

findScopeByOwner :: AmaruJournal -> Text -> Maybe AmaruScope
findScopeByOwner j ownerHex =
    find (\s -> ascOwner s == Just ownerHex) (ajScopes j)

findScopeByRefOutref
    :: AmaruJournal -> Text -> Maybe (AmaruScope, Text)
findScopeByRefOutref j outref =
    let check s
            | asDeployedAt (ascTreasuryScript s) == outref =
                Just (s, "treasury_script")
            | asDeployedAt (ascPermissionsScript s) == outref =
                Just (s, "permissions_script")
            | asDeployedAt (ascRegistryScript s) == outref =
                Just (s, "registry_script")
            | otherwise = Nothing
    in  case mapMaybe check (ajScopes j) of
            (m : _) -> Just m
            [] -> Nothing
