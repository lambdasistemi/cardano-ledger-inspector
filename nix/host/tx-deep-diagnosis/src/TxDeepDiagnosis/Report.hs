{-# LANGUAGE OverloadedStrings #-}

module TxDeepDiagnosis.Report
    ( renderReport
    ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Char8 as BC
import Data.List (intercalate, sortBy)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, fromMaybe, isJust)
import Data.Ord (Down (..), comparing)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Text.Printf (printf)

import TxDeepDiagnosis.Conway
import TxDeepDiagnosis.Diagnosis
import TxDeepDiagnosis.Registry
import TxDeepDiagnosis.Types

renderReport :: Diagnosis -> Text
renderReport dg = Text.unlines
    [ ""
    , bar "Layer 0 — wire format"
    , layer0 (dgTx dg)
    , bar "Layer 1 — decoded ledger fields"
    , layer1 (dgTx dg)
    , bar "Layer 2 — clusters by (payment, stake)"
    , layer2 (dgClusters dg)
    , bar "Layer 3 — datum hash xref"
    , layer3 (dgTx dg) (dgDatumExtractedHashes dg)
    , bar "Layer 4 — script identity (vendored blueprints + Amaru journal)"
    , layer4 (dgScriptIdentifications dg)
    , bar "Layer 5 — reference inputs vs deployment outrefs"
    , layer5 (dgRefInputIdentifications dg)
    , bar "Layer 6 — required signers labelled"
    , layer6 (dgRequiredSignerScopes dg)
    , bar "Layer 7 — resolved producer-tx context"
    , layer7 (dgResolvedInputs dg) (dgResolvedCollateral dg)
    , bar "Layer 8 — value reconciliation"
    , layer8 (dgBalanceCheck dg)
    , bar "Layer 9 — diagnosis"
    , layer9 dg
    ]
  where
    bar t = Text.replicate 78 "═" <> "\n" <> "  " <> t <> "\n" <> Text.replicate 78 "═"

layer0 :: DecodedTx -> Text
layer0 tx = Text.unlines
    [ "  raw size:        " <> tshow (txRawSize tx) <> " bytes"
    , "  validity flag:   " <> tshow (txValidityFlag tx)
    , "  TTL:             " <> maybe "(none)" tshow (txTtl tx)
    ]

layer1 :: DecodedTx -> Text
layer1 tx = Text.unlines $
    [ "  inputs:          " <> tshow (length (txInputs tx))
    ] ++ map (\o -> "    - " <> renderOutRef o) (txInputs tx) ++
    [ "  collateral:      " <> tshow (length (txCollateralInputs tx))
    ] ++ map (\o -> "    - " <> renderOutRef o) (txCollateralInputs tx) ++
    [ "  reference inputs:" <> tshow (length (txReferenceInputs tx))
    ] ++ map (\o -> "    - " <> renderOutRef o) (txReferenceInputs tx) ++
    [ "  outputs:         " <> tshow (length (txOutputs tx))
    , "  fee:             " <> renderAda (txFee tx) <> " ADA"
    , "  withdrawals:     " <> tshow (length (txWithdrawals tx))
    ] ++ map (\(c, l) -> "    - " <> credToText c <> " → " <> renderAda l <> " ADA") (txWithdrawals tx) ++
    [ "  required signers:" <> tshow (length (txRequiredSigners tx))
    ] ++ map (\h -> "    - " <> hashHex h) (txRequiredSigners tx) ++
    [ "  total_collateral:" <> maybe "(none)" (\l -> renderAda l <> " ADA") (txTotalCollateral tx)
    , "  collateral_return: " <> maybe "(none)" renderOutShort (txCollateralReturn tx)
    , "  aux_data_hash:   " <> maybe "(none)" hashHex (txAuxiliaryDataHash tx)
    , "  script_data_hash:" <> maybe "(none)" hashHex (txScriptDataHash tx)
    ]

renderOutShort :: Output -> Text
renderOutShort o = renderAddr (outAddress o) <> "  " <> renderAda (valLovelace (outValue o)) <> " ADA"

layer2 :: [Cluster] -> Text
layer2 cs = Text.unlines $ map renderCluster (sortBy (comparing (Down . valLovelace . clusterTotal)) cs)
  where
    renderCluster c = Text.unlines
        [ "  cluster " <> credToText (clusterPayment c)
            <> " / " <> maybe "(no stake)" credToText (clusterStake c)
            <> selfStaked
        , "    members:    outputs " <> Text.intercalate ", " (map tshow (clusterMembers c))
        , "    total ADA:  " <> renderAda (valLovelace (clusterTotal c))
        , "    assets:     " <> tshow (Map.size (valAssets (clusterTotal c)))
        ]
      where
        selfStaked = case (clusterPayment c, clusterStake c) of
            (ScriptCred a, Just (ScriptCred b)) | a == b -> "  [self-staked]"
            _ -> ""

layer3 :: DecodedTx -> Map.Map Int [Hash28] -> Text
layer3 tx datumHashes =
    let credSet = collectAllCredHashes tx
        renderEntry (i, hs) = Text.unlines
            [ "  output #" <> tshow i <> " datum carries " <> tshow (length hs) <> " 28-byte hash(es):"
            , Text.unlines [ "    - " <> hashHex h <> " " <> matchLabel h
                           | h <- hs ]
            ]
        matchLabel h = case classify h credSet of
            "" -> "(no tx-level match)"
            ms -> "← matches " <> ms
    in Text.concat (map renderEntry (Map.toList datumHashes))

collectAllCredHashes :: DecodedTx -> Map.Map Hash28 [Text]
collectAllCredHashes tx =
    let labelFromOutput i o =
            let pcs = case addrPayment (outAddress o) of
                    KeyCred h -> [(h, "output #" <> tshow i <> " payment key")]
                    ScriptCred h -> [(h, "output #" <> tshow i <> " payment script")]
                ss = case addrStake (outAddress o) of
                    Just (KeyCred h) -> [(h, "output #" <> tshow i <> " stake key")]
                    Just (ScriptCred h) -> [(h, "output #" <> tshow i <> " stake script")]
                    _ -> []
            in pcs ++ ss
        outsLabels = concatMap (\(i, o) -> labelFromOutput i o) (zip [1 :: Int ..] (txOutputs tx))
        sigLabels = [(h, "required signer") | h <- txRequiredSigners tx]
        wdLabels = catMaybes
            [ case c of
                ScriptCred h -> Just (h, "withdrawal script")
                KeyCred h -> Just (h, "withdrawal key")
            | (c, _) <- txWithdrawals tx
            ]
        all_ = outsLabels ++ sigLabels ++ wdLabels
    in Map.fromListWith (++) [(h, [l]) | (h, l) <- all_]

classify :: Hash28 -> Map.Map Hash28 [Text] -> Text
classify h m = case Map.lookup h m of
    Just labels -> Text.intercalate "; " labels
    Nothing -> ""

layer4 :: [(Hash28, Identification)] -> Text
layer4 ids = Text.unlines $ map render ids
  where
    render (h, id_) = "  " <> hashHex h <> "  →  " <> renderId id_
    renderId (IdValidator v) = "BLUEPRINT MATCH: " <> rvBlueprint v <> " :: " <> rvValidator v
        <> maybe "" (\l -> " [" <> l <> "]") (rvLabel v)
    renderId (IdInstance i mScope) = "INSTANCE: " <> riLabel i
        <> "  (template " <> riBlueprint i <> " :: " <> riValidator i <> ")"
        <> maybe "" (\s -> "  [scope " <> ascName s <> "]") mScope
    renderId (IdAmaruRole s role) = "AMARU JOURNAL: " <> ascName s <> " " <> role
    renderId IdUnknown = "(unknown — not in registry)"

layer5 :: [(OutRef, Maybe (AmaruScope, Text))] -> Text
layer5 ids = Text.unlines $ map render ids
  where
    render (oref, mScope) =
        let line = "  " <> renderOutRef oref <> "  →  "
        in line <> case mScope of
            Just (s, role) -> "Amaru " <> ascName s <> " " <> role
            Nothing -> "(no journal match)"

layer6 :: [(Hash28, Maybe AmaruScope)] -> Text
layer6 xs = Text.unlines $ map render xs
  where
    render (h, mScope) = "  " <> hashHex h <> "  →  "
        <> maybe "(no Amaru scope match)" (\s -> "Amaru " <> ascName s <> " owner") mScope

layer7 :: [ResolvedInput] -> [ResolvedInput] -> Text
layer7 ins coll = Text.unlines $
    [ "  spend inputs:"
    ] ++ map renderRI ins ++
    [ ""
    , "  collateral inputs:"
    ] ++ map renderRI coll
  where
    renderRI ri = "    " <> renderOutRef (riOutRef ri) <> "  "
        <> case riError ri of
            Just e -> "ERROR: " <> e
            Nothing -> case riValueLovelace ri of
                Just l -> renderAda l <> " ADA"
                    <> maybe "" (\a -> " at " <> a) (riAddressText ri)
                Nothing -> "(resolved but no lovelace value)"

layer8 :: BalanceCheck -> Text
layer8 bc = Text.unlines
    [ "  total in (resolved): " <> renderAda (bcTotalIn bc) <> " ADA"
        <> "  (" <> tshow (bcResolvedInputCount bc) <> "/" <> tshow (bcExpectedInputCount bc) <> " inputs resolved)"
    , "  total out:           " <> renderAda (bcTotalOut bc) <> " ADA"
    , "  fee:                 " <> renderAda (bcFee bc) <> " ADA"
    , "  withdrawals:         " <> renderAda (bcWithdrawals bc) <> " ADA"
    , ""
    , "  in − out − fee + wd: " <> renderAda (bcDelta bc) <> " ADA"
        <> if bcDelta bc == 0
            then "  ✓ balanced"
            else "  ✗ UNBALANCED — should be 0"
    , ""
    , "  collateral inputs resolved: " <> tshow (bcCollateralResolved bc)
    , "  collateral inputs exist on chain: "
        <> if bcCollateralExists bc then "yes" else "NO — references a non-existent UTxO"
    ]

layer9 :: Diagnosis -> Text
layer9 dg = Text.unlines $ catMaybes
    [ if bcDelta bc /= 0
        then Just $ "  ⚠ tx does NOT balance by " <> renderAda (abs (bcDelta bc)) <> " ADA — would be rejected by ledger"
        else Nothing
    , if not (bcCollateralExists bc) && bcCollateralResolved bc
        then Just $ "  ⚠ collateral input does not exist on chain — placeholder or stale outref"
        else Nothing
    , if bcResolvedInputCount bc < bcExpectedInputCount bc
        then Just $ "  ⚠ only " <> tshow (bcResolvedInputCount bc) <> "/"
            <> tshow (bcExpectedInputCount bc) <> " inputs resolved — analysis is partial"
        else Nothing
    , Just $ "  identified " <> tshow (length [() | (_, IdValidator _) <- dgScriptIdentifications dg])
        <> " script(s) by direct blueprint match"
    , Just $ "  identified " <> tshow (length [() | (_, IdInstance _ _) <- dgScriptIdentifications dg])
        <> " script(s) as parameterized instances via the registry"
    , Just $ "  matched " <> tshow (length [() | (_, IdAmaruRole _ _) <- dgScriptIdentifications dg])
        <> " script(s) directly to Amaru journal roles"
    ]
  where
    bc = dgBalanceCheck dg

renderOutRef :: OutRef -> Text
renderOutRef o = hashHex (outRefTx o) <> "#" <> tshow (outRefIx o)

renderAddr :: Address -> Text
renderAddr a = credToText (addrPayment a) <> "/"
    <> maybe "(none)" credToText (addrStake a)

renderAda :: Lovelace -> Text
renderAda l =
    let s = printf "%.6f" (fromIntegral l / 1e6 :: Double) :: String
    in Text.pack s

tshow :: Show a => a -> Text
tshow = Text.pack . show
