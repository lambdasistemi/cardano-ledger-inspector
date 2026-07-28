{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Conway.Inspector.Review
    ( ControlCategory (..)
    , ControlGroup (..)
    , EvidenceProvenance (..)
    , NetSignerValue (..)
    , ReviewResult (..)
    , projectReview
    , reviewVersion
    )
import Data.Aeson ((.=))
import Data.Aeson qualified as Aeson
import Test.Hspec
    ( Spec
    , describe
    , hspec
    , it
    , shouldBe
    )

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
    describe "ControlCategory JSON encoding" $ do
        it "encodes signer_controlled" $
            Aeson.toJSON SignerControlled
                `shouldBe` Aeson.String
                    "signer_controlled"
        it "encodes external_key" $
            Aeson.toJSON ExternalKey
                `shouldBe` Aeson.String
                    "external_key"
        it "encodes script" $
            Aeson.toJSON Script
                `shouldBe` Aeson.String "script"
        it "encodes bootstrap" $
            Aeson.toJSON Bootstrap
                `shouldBe` Aeson.String "bootstrap"
        it "encodes unknown" $
            Aeson.toJSON Unknown
                `shouldBe` Aeson.String "unknown"
    describe "EvidenceProvenance JSON encoding" $ do
        it "encodes ledger_proven" $
            Aeson.toJSON LedgerProven
                `shouldBe` Aeson.String
                    "ledger_proven"
        it "encodes context_proven" $
            Aeson.toJSON ContextProven
                `shouldBe` Aeson.String
                    "context_proven"
        it "encodes registry_decoded" $
            Aeson.toJSON RegistryDecoded
                `shouldBe` Aeson.String
                    "registry_decoded"
        it "encodes metadata_claim" $
            Aeson.toJSON MetadataClaim
                `shouldBe` Aeson.String
                    "metadata_claim"
        it "encodes heuristic" $
            Aeson.toJSON Heuristic
                `shouldBe` Aeson.String "heuristic"
    describe "review version" $
        it "encodes as cardano-tx-review/v1" $
            Aeson.toJSON reviewVersion
                `shouldBe` Aeson.String
                    "cardano-tx-review/v1"
    describe "lovelace values" $
        it "encodes as lossless decimal strings" $
            Aeson.toJSON
                ( NetSignerValue
                    True
                    (Just "9007199254740993")
                    "all regular inputs resolved"
                )
                `shouldBe` Aeson.object
                    [ "provable" .= True
                    , "lovelace"
                        .= Aeson.String
                            "9007199254740993"
                    , "note"
                        .= Aeson.String
                            "all regular inputs resolved"
                    ]
    describe "unprovable net signer value" $
        it "encodes lovelace as JSON null with note" $
            Aeson.toJSON
                ( NetSignerValue
                    False
                    Nothing
                    "missing input context, net signer gain/loss unprovable"
                )
                `shouldBe` Aeson.object
                    [ "provable" .= False
                    , "lovelace" .= Aeson.Null
                    , "note"
                        .= Aeson.String
                            "missing input context, net signer gain/loss unprovable"
                    ]
    describe "ControlGroup deterministic JSON" $
        it "has a stable shape" $
            Aeson.toJSON testControlGroup
                `shouldBe` Aeson.object
                    [ "category"
                        .= Aeson.String
                            "signer_controlled"
                    , "addresses"
                        .= [Aeson.String "addr1_test"]
                    , "output_indices"
                        .= ([0, 1] :: [Int])
                    , "output_count" .= (2 :: Int)
                    , "lovelace"
                        .= Aeson.String "1041000000"
                    , "asset_class_count" .= (0 :: Int)
                    , "assets" .= Aeson.object []
                    , "role"
                        .= Aeson.String "continuation"
                    , "role_provenance"
                        .= Aeson.String "context_proven"
                    , "evidence"
                        .= [ Aeson.String "ledger_proven"
                           , Aeson.String "context_proven"
                           ]
                    ]
    describe "ControlGroup per-asset amounts" $ do
        it "T168 sums quantities across grouped outputs" $
            Aeson.toJSON (head (rrControlGroups multiAssetReview))
                `shouldBe` Aeson.object
                    [ "category"
                        .= Aeson.String "external_key"
                    , "addresses"
                        .= [Aeson.String "addr1_shared"]
                    , "output_indices"
                        .= ([0, 1] :: [Int])
                    , "output_count" .= (2 :: Int)
                    , "lovelace"
                        .= Aeson.String "3000000"
                    , "asset_class_count" .= (2 :: Int)
                    , "assets"
                        .= Aeson.object
                            [ "aaaa"
                                .= Aeson.object
                                    ["01" .= Aeson.String "300"]
                            , "bbbb"
                                .= Aeson.object
                                    ["02" .= Aeson.String "50"]
                            ]
                    , "role"
                        .= Aeson.String
                            "external_key_destination"
                    , "role_provenance"
                        .= Aeson.String "ledger_proven"
                    , "evidence"
                        .= [Aeson.String "ledger_proven"]
                    ]
        it "T169 emits empty assets object for ada-only group" $
            Aeson.toJSON (head (rrControlGroups adaOnlyReview))
                `shouldBe` Aeson.object
                    [ "category"
                        .= Aeson.String "external_key"
                    , "addresses"
                        .= [Aeson.String "addr1_bare"]
                    , "output_indices"
                        .= ([0] :: [Int])
                    , "output_count" .= (1 :: Int)
                    , "lovelace"
                        .= Aeson.String "5000000"
                    , "asset_class_count" .= (0 :: Int)
                    , "assets" .= Aeson.object []
                    , "role"
                        .= Aeson.String
                            "external_key_destination"
                    , "role_provenance"
                        .= Aeson.String "ledger_proven"
                    , "evidence"
                        .= [Aeson.String "ledger_proven"]
                    ]
        it "T170 counts asset classes with unparseable quantities" $
            Aeson.toJSON
                (head (rrControlGroups unparseableQtyReview))
                `shouldBe` Aeson.object
                    [ "category"
                        .= Aeson.String "external_key"
                    , "addresses"
                        .= [Aeson.String "addr1_mixed"]
                    , "output_indices"
                        .= ([0] :: [Int])
                    , "output_count" .= (1 :: Int)
                    , "lovelace"
                        .= Aeson.String "1000000"
                    , "asset_class_count" .= (2 :: Int)
                    , "assets"
                        .= Aeson.object
                            [ "aaaa"
                                .= Aeson.object
                                    ["01" .= Aeson.String "100"]
                            , "bbbb"
                                .= Aeson.object
                                    ["02" .= Aeson.String "0"]
                            ]
                    , "role"
                        .= Aeson.String
                            "external_key_destination"
                    , "role_provenance"
                        .= Aeson.String "ledger_proven"
                    , "evidence"
                        .= [Aeson.String "ledger_proven"]
                    ]
  where
    multiAssetReview =
        projectReview
            mempty
            Nothing
            Nothing
            ( Aeson.object
                [ "tx_id" .= Aeson.String "test_tx"
                , "body_hash" .= Aeson.String "test_hash"
                , "fee_lovelace" .= Aeson.String "200000"
                , "value"
                    .= Aeson.object
                        [ "outputs"
                            .= [ Aeson.object
                                    [ "index" .= (0 :: Int)
                                    , "bucket"
                                        .= Aeson.String
                                            "external_key"
                                    , "address_hex"
                                        .= Aeson.String
                                            "addr1_shared"
                                    , "coin_lovelace"
                                        .= Aeson.String
                                            "1000000"
                                    , "assets"
                                        .= Aeson.object
                                            [ "aaaa"
                                                .= Aeson.object
                                                    [ "01"
                                                        .= Aeson.String
                                                            "100"
                                                    ]
                                            ]
                                    ]
                               , Aeson.object
                                    [ "index" .= (1 :: Int)
                                    , "bucket"
                                        .= Aeson.String
                                            "external_key"
                                    , "address_hex"
                                        .= Aeson.String
                                            "addr1_shared"
                                    , "coin_lovelace"
                                        .= Aeson.String
                                            "2000000"
                                    , "assets"
                                        .= Aeson.object
                                            [ "aaaa"
                                                .= Aeson.object
                                                    [ "01"
                                                        .= Aeson.String
                                                            "200"
                                                    ]
                                            , "bbbb"
                                                .= Aeson.object
                                                    [ "02"
                                                        .= Aeson.String
                                                            "50"
                                                    ]
                                            ]
                                    ]
                               ]
                        ]
                ]
            )
    adaOnlyReview =
        projectReview
            mempty
            Nothing
            Nothing
            ( Aeson.object
                [ "tx_id" .= Aeson.String "test_tx"
                , "body_hash" .= Aeson.String "test_hash"
                , "fee_lovelace" .= Aeson.String "200000"
                , "value"
                    .= Aeson.object
                        [ "outputs"
                            .= [ Aeson.object
                                    [ "index" .= (0 :: Int)
                                    , "bucket"
                                        .= Aeson.String
                                            "external_key"
                                    , "address_hex"
                                        .= Aeson.String
                                            "addr1_bare"
                                    , "coin_lovelace"
                                        .= Aeson.String
                                            "5000000"
                                    ]
                               ]
                        ]
                ]
            )
    unparseableQtyReview =
        projectReview
            mempty
            Nothing
            Nothing
            ( Aeson.object
                [ "tx_id" .= Aeson.String "test_tx"
                , "body_hash" .= Aeson.String "test_hash"
                , "fee_lovelace" .= Aeson.String "200000"
                , "value"
                    .= Aeson.object
                        [ "outputs"
                            .= [ Aeson.object
                                    [ "index" .= (0 :: Int)
                                    , "bucket"
                                        .= Aeson.String
                                            "external_key"
                                    , "address_hex"
                                        .= Aeson.String
                                            "addr1_mixed"
                                    , "coin_lovelace"
                                        .= Aeson.String
                                            "1000000"
                                    , "assets"
                                        .= Aeson.object
                                            [ "aaaa"
                                                .= Aeson.object
                                                    [ "01"
                                                        .= Aeson.String
                                                            "100"
                                                    ]
                                            , "bbbb"
                                                .= Aeson.object
                                                    [ "02"
                                                        .= Aeson.String
                                                            "not_a_number"
                                                    ]
                                            ]
                                    ]
                               ]
                        ]
                ]
            )
    testControlGroup =
        ControlGroup
            { cgCategory = SignerControlled
            , cgAddresses = ["addr1_test"]
            , cgOutputIndices = [0, 1]
            , cgOutputCount = 2
            , cgLovelace = "1041000000"
            , cgAssets = mempty
            , cgRole = "continuation"
            , cgRoleProvenance = ContextProven
            , cgEvidence =
                [LedgerProven, ContextProven]
            }
