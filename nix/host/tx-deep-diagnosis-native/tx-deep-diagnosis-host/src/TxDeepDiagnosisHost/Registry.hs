{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosisHost.Registry
    ( ProtocolRegistry (..)
    , RegistryValidator (..)
    , RegistryInstance (..)
    , AmaruScope (..)
    , AmaruScript (..)
    , AmaruJournal (..)
    , loadRegistry
    , identifyByHash
    , findScopeByOwner
    , findScopeByRefOutref
    , Identification (..)
    ) where

import Data.Aeson (FromJSON (..), eitherDecodeFileStrict, withObject, (.:), (.:?), (.!=))
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
    }
    deriving (Show)

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
        pure AmaruJournal { ajScopeOwners = owners, ajScopes = scopes }
      where
        parseScope (k, v) =
            let name = Key.toText k
            in case A.parseEither (parseScopeBody name) v of
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

loadRegistry :: FilePath -> IO ProtocolRegistry
loadRegistry root = do
    let registryPath = root </> "registry.json"
        amaruPath = root </> "amaru-treasury" </> "journal-2026.json"
    rf <- do
        exists <- doesFileExist registryPath
        if exists
            then either (\e -> error ("registry.json decode: " <> e)) id <$> eitherDecodeFileStrict registryPath
            else pure (RegistryFile [] [])
    aj <- do
        exists <- doesFileExist amaruPath
        if exists
            then either (const Nothing) Just <$> eitherDecodeFileStrict amaruPath
            else pure Nothing
    pure ProtocolRegistry
        { prValidators = rfValidators rf
        , prInstances = rfInstances rf
        , prAmaru = aj
        }

data Identification
    = IdValidator !RegistryValidator
    | IdInstance !RegistryInstance !(Maybe AmaruScope)
    | IdAmaruRole !AmaruScope !Text
    | IdUnknown
    deriving (Show)

identifyByHash :: ProtocolRegistry -> Text -> Identification
identifyByHash reg hh =
    case find ((== hh) . rvHashHex) (prValidators reg) of
        Just v -> IdValidator v
        Nothing -> case find ((== hh) . riHashHex) (prInstances reg) of
            Just inst ->
                let scope = case prAmaru reg of
                        Just j -> findAmaruScopeByTreasury j hh
                        Nothing -> Nothing
                in IdInstance inst scope
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
    in case mapMaybe check (ajScopes j) of
        (m:_) -> Just m
        [] -> Nothing

findScopeByOwner :: AmaruJournal -> Text -> Maybe AmaruScope
findScopeByOwner j ownerHex =
    find (\s -> ascOwner s == Just ownerHex) (ajScopes j)

findScopeByRefOutref :: AmaruJournal -> Text -> Maybe (AmaruScope, Text)
findScopeByRefOutref j outref =
    let check s
            | asDeployedAt (ascTreasuryScript s) == outref = Just (s, "treasury_script")
            | asDeployedAt (ascPermissionsScript s) == outref = Just (s, "permissions_script")
            | asDeployedAt (ascRegistryScript s) == outref = Just (s, "registry_script")
            | otherwise = Nothing
    in case mapMaybe check (ajScopes j) of
        (m:_) -> Just m
        [] -> Nothing
