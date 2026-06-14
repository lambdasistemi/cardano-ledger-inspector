module Main (main) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), Replacement(..), joinWith, replaceAll, trim) as String
import Data.String.CodeUnits as StringCodeUnits
import Effect (Effect)
import Effect.Aff (attempt)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import FFI.Blockfrost (Network(..), networkName)
import FFI.Clipboard (copy) as Clipboard
import FFI.Inspector (InspectorResult, runLedgerOperation)
import FFI.Json (Browser, Identification, IntentSummary, RdfGraph, Validation, WitnessPlan, inspect, operationArgsMerged, operationArgsWithPath, operationBrowser, operationIdentification, operationInspection, operationIntentSummary, operationRdfGraph, operationValidation, operationWitnessPlan, pretty, providerResolutionErrorArgs) as Json
import FFI.OverlayBook (OverlayPart)
import FFI.OverlayBook as OverlayBook
import FFI.RdfShapes as RdfShapes
import FFI.Storage as Storage
import Provider (Provider(..))
import Provider as Provider
import Routing (Route(..))
import Routing as Routing
import Shell as Shell
import Theme as Theme
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.VDom.Driver (runUI)
import Web.Event.Event as Event
import Web.DOM.ParentNode (QuerySelector(..))
import Web.UIEvent.MouseEvent (MouseEvent)
import Web.UIEvent.MouseEvent as MouseEvent

blockfrostKey :: String
blockfrostKey = "blockfrost_project_id"

koiosKey :: String
koiosKey = "koios_bearer_token"

providerKey :: String
providerKey = "provider"

networkKey :: String
networkKey = "network"

persistKeysStorageKey :: String
persistKeysStorageKey = "persist_api_keys"

cardanoShaclShapes :: String
cardanoShaclShapes =
  "@prefix cardano: <https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#> .\n"
    <> "@prefix sh: <http://www.w3.org/ns/shacl#> .\n"
    <> "\n"
    <> "cardano:TransactionShape\n"
    <> "  a sh:NodeShape ;\n"
    <> "  sh:targetClass cardano:Transaction ;\n"
    <> "  sh:property cardano:TransactionIdShape .\n"
    <> "\n"
    <> "cardano:TransactionIdShape\n"
    <> "  sh:path cardano:hasTxId ;\n"
    <> "  sh:minCount 1 ;\n"
    <> "  sh:class cardano:Identifier ;\n"
    <> "  sh:message \"Cardano transactions must reference a transaction id identifier.\" .\n"

main :: Effect Unit
main = HA.runHalogenAff do
  body    <- HA.awaitBody
  app     <- HA.selectElement (QuerySelector "#app")
  persist <- liftEffect (Storage.getItem persistKeysStorageKey)
  let persistInitial = persist == "true"
  bf   <- liftEffect
    (if persistInitial then Storage.getItem blockfrostKey else pure "")
  kOS  <- liftEffect
    (if persistInitial then Storage.getItem koiosKey else pure "")
  prov <- liftEffect (Storage.getItem providerKey)
  net  <- liftEffect (Storage.getItem networkKey)
  route <- liftEffect Routing.currentRoute
  routeBase <- liftEffect Routing.currentBasePath
  theme <- liftEffect Shell.initialTheme
  let initialProv = case prov of
        "Koios"      -> Koios
        _            -> Blockfrost
      initialNetwork = case net of
        "preprod" -> Preprod
        "preview" -> Preview
        _         -> Mainnet
      mountTarget = case app of
        Just el -> el
        Nothing -> body
  runUI
    ( inspectorComponent
        { bf
        , koios: kOS
        , prov: initialProv
        , network: initialNetwork
        , persistKeys: persistInitial
        , route
        , routeBase
        , theme
        }
    ) unit mountTarget

data Mode = ByHash | ByHex

derive instance eqMode :: Eq Mode

type State =
  { provider :: Provider
  , blockfrostKey :: String
  , koiosBearer :: String
  , persistKeys :: Boolean
  , mode :: Mode
  , network :: Network
  , txHash :: String
  , txHex :: String
  , result :: Maybe InspectorResult
  , txCbor :: Maybe String
  , operationArgs :: String
  , browser :: Maybe Json.Browser
  , identification :: Maybe Json.Identification
  , intent :: Maybe Json.IntentSummary
  , witnessPlan :: Maybe Json.WitnessPlan
  , validation :: Maybe Json.Validation
  , rdf :: Maybe Json.RdfGraph
  , sparqlLens :: Maybe SparqlLens
  , resolvedLabelsLens :: Maybe ResolvedLabelsLens
  , typedFieldsLens :: Maybe TypedFieldsLens
  , shaclConformance :: Maybe ShaclConformance
  , overlayInput :: String
  , overlayParts :: Array OverlayPart
  , selectedOverlayPartIds :: Array String
  , overlayError :: Maybe String
  , browserNodes :: Array BrowserNode
  , expandedPaths :: Array String
  , running :: Boolean
  , copied :: Boolean
  , copiedPath :: Maybe String
  , browserPath :: String
  , fetchError :: Maybe String
  , route :: Route
  , routeBase :: String
  , theme :: Theme.Theme
  }

type BrowserNode =
  { path :: String
  , browser :: Json.Browser
  }

type SparqlLens =
  { rows :: Array RdfShapes.TransactionOutputRow
  , error :: Maybe String
  }

type ResolvedLabelsLens =
  { rows :: Array RdfShapes.ResolvedLabelRow
  , error :: Maybe String
  }

type TypedFieldsLens =
  { rows :: Array RdfShapes.TypedFieldRow
  , error :: Maybe String
  }

type ShaclConformance =
  { shapeLabels :: Array String
  , report :: Maybe RdfShapes.ShaclReport
  , error :: Maybe String
  }

type InitialKeys =
  { bf :: String
  , koios :: String
  , prov :: Provider
  , network :: Network
  , persistKeys :: Boolean
  , route :: Route
  , routeBase :: String
  , theme :: Theme.Theme
  }

data Action
  = SetBlockfrostKey String
  | SetKoiosBearer String
  | SelectProvider Provider
  | TogglePersist Boolean
  | SelectMode Mode
  | SelectNetwork Network
  | SetTxHash String
  | SetTxHex String
  | SetOverlayInput String
  | ImportOverlayBook
  | LoadAmaruOverlayBook
  | LoadSundaeSwapBlueprintBook
  | LoadShaclShapesBook
  | ToggleOverlayPart String Boolean
  | ApplySelectedBooks
  | Decode
  | Copy
  | CopyValue String String
  | BrowseJson String
  | Navigate Route MouseEvent
  | ToggleTheme

inspectorComponent
  :: forall q i o m
   . MonadAff m
  => InitialKeys
  -> H.Component q i o m
inspectorComponent initial =
  H.mkComponent
    { initialState: \_ ->
        { provider: initial.prov
        , blockfrostKey: initial.bf
        , koiosBearer: initial.koios
        , persistKeys: initial.persistKeys
        , mode: ByHash
        , network: initial.network
        , txHash: ""
        , txHex: ""
        , result: Nothing
        , txCbor: Nothing
        , operationArgs: "{}"
        , browser: Nothing
        , identification: Nothing
        , intent: Nothing
        , witnessPlan: Nothing
        , validation: Nothing
        , rdf: Nothing
        , sparqlLens: Nothing
        , resolvedLabelsLens: Nothing
        , typedFieldsLens: Nothing
        , shaclConformance: Nothing
        , overlayInput: ""
        , overlayParts: []
        , selectedOverlayPartIds: []
        , overlayError: Nothing
        , browserNodes: []
        , expandedPaths: []
        , running: false
        , copied: false
        , copiedPath: Nothing
        , browserPath: "[]"
        , fetchError: Nothing
        , route: initial.route
        , routeBase: initial.routeBase
        , theme: initial.theme
        }
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }
  where

  render state =
    HH.div
      [ classNames [ "shell-root" ] ]
      [ Shell.topbar
          state.route
          { themeLabel: Shell.themeLabel state.theme
          , basePath: state.routeBase
          , onToggleTheme: ToggleTheme
          , onNavigate: Navigate
          }
      , HH.main
          [ classNames [ "page-frame", "shell-main" ] ]
          [ case state.route of
              RouteInspect -> renderInspector state
              RouteSettings -> renderSettings state
              RouteLibrary -> Shell.placeholderPage "Library"
          ]
      , Shell.siteFooter
      ]

  renderInspector state =
    HH.div
      [ classNames [ "app-shell" ] ]
      [ HH.section
          [ classNames [ "intro-strip" ] ]
          [ HH.div_
              [ HH.h1_ [ HH.text "Conway tx inspector" ]
              , HH.p_
                  [ HH.text
                      "Decode, inspect, and validate Conway transaction CBOR with explicit chain-data context."
                  ]
              ]
          , HH.div
              [ classNames [ "tech-pills" ] ]
              [ HH.span_ [ HH.text "CBOR" ]
              , HH.span_ [ HH.text "context-aware" ]
              , HH.span_ [ HH.text "RDF views" ]
              ]
          ]
      , renderSettingsSummary state
      , HH.div
          [ classNames [ "workspace" ] ]
          [ HH.div
              [ classNames [ "workspace-main" ] ]
              (renderWorkspaceMain state)
          ]
      ]

  renderSettings state =
    HH.div
      [ classNames [ "app-shell", "settings-page" ] ]
      [ HH.section
          [ classNames [ "intro-strip" ] ]
          [ HH.div_
              [ HH.h1_ [ HH.text "Settings" ]
              , HH.p_
                  [ HH.text
                      "Configure the chain-data provider, network, and credential persistence used by transaction decoding."
                  ]
              ]
          ]
      , HH.div
          [ classNames [ "settings-layout" ] ]
          [ renderProvider state ]
      ]

  renderSettingsSummary state =
    HH.section
      [ classNames [ "settings-summary" ]
      , mdSurface "provider"
      ]
      [ HH.div
          [ classNames [ "settings-summary-copy" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Active chain data" ]
          , HH.strong_
              [ HH.text
                  (Provider.providerName state.provider <> " / " <> networkName state.network)
              ]
          ]
      , HH.a
          [ classNames [ "header-link" ]
          , HP.href (state.routeBase <> Routing.routePath RouteSettings)
          , HE.onClick (Navigate RouteSettings)
          ]
          [ HH.text "Settings" ]
      ]

  renderWorkspaceMain state =
    case state.fetchError of
      Just _ -> [ renderResult state, renderModeTabs state ]
      Nothing -> case state.result of
        Just _  -> [ renderResult state, renderModeTabs state ]
        Nothing -> [ renderModeTabs state, renderResult state ]

  renderProvider state =
    HH.section
      [ classNames [ "panel", "provider-panel" ]
      , mdSurface "provider"
      ]
      [ HH.div
          [ classNames [ "panel-heading" ] ]
          [ HH.h2_ [ HH.text "Chain data" ]
          , HH.p_ [ HH.text "Credentials stay in memory unless persistence is enabled." ]
          ]
      , HH.fieldset
          [ classNames [ "control-group" ] ]
          [ HH.legend_ [ HH.text "Provider" ]
          , HH.div
              [ classNames [ "option-stack" ] ]
              [ providerRadio state Blockfrost "Blockfrost"
              , providerRadio state Koios      "Koios"
              ]
          ]
      , HH.div
          [ classNames [ "field-stack" ] ]
          [ case state.provider of
              Blockfrost ->
                HH.label
                  [ classNames [ "field-label" ] ]
                  [ HH.text "Blockfrost project ID"
                  , HH.a
                      [ HP.href "https://blockfrost.io/dashboard"
                      , HP.target "_blank"
                      , HP.rel "noopener noreferrer"
                      ]
                      [ HH.text "Dashboard" ]
                  ]
              Koios ->
                HH.label
                  [ classNames [ "field-label" ] ]
                  [ HH.text "Koios bearer token"
                  , HH.a
                      [ HP.href "https://koios.rest/auth/Auth.html"
                      , HP.target "_blank"
                      , HP.rel "noopener noreferrer"
                      ]
                      [ HH.text "Auth" ]
                  ]
          , case state.provider of
              Blockfrost ->
                HH.input
                  [ HP.type_ HP.InputPassword
                  , HP.placeholder "mainnet... / preprod... / preview..."
                  , HP.value state.blockfrostKey
                  , HE.onValueInput SetBlockfrostKey
                  ]
              Koios ->
                HH.input
                  [ HP.type_ HP.InputPassword
                  , HP.placeholder "eyJhbGciOi..."
                  , HP.value state.koiosBearer
                  , HE.onValueInput SetKoiosBearer
                  ]
          ]
      , HH.fieldset
          [ classNames [ "control-group" ] ]
          [ HH.legend_ [ HH.text "Network" ]
          , HH.div
              [ classNames [ "option-stack", "compact-options" ] ]
              [ networkRadio state Mainnet "mainnet"
              , networkRadio state Preprod "preprod"
              , networkRadio state Preview "preview"
              ]
          ]
      , renderPersistToggle state
      ]

  renderPersistToggle state =
    HH.div
      [ classNames [ "persist-block" ] ]
      [ HH.label
          [ classNames [ "switch-row" ] ]
          [ HH.input
              [ HP.type_ HP.InputCheckbox
              , HH.attr (HH.AttrName "role") "switch"
              , HP.checked state.persistKeys
              , HE.onChecked TogglePersist
              ]
          , HH.span_ [ HH.text "Persist API credentials" ]
          ]
      , HH.p
          [ classNames [ "warning-note" ] ]
          [ HH.strong_ [ HH.text "Warning: " ]
          , HH.text
              "when enabled, credentials are saved in localStorage in cleartext. When disabled, they stay in memory only."
          ]
      ]

  providerRadio state prov label =
    HH.label
      [ choiceClass (state.provider == prov) ]
      [ HH.input
          [ HP.type_ HP.InputRadio
          , HP.name "provider"
          , HP.checked (state.provider == prov)
          , HE.onChange (\_ -> SelectProvider prov)
          ]
      , HH.span
          [ classNames [ "choice-copy" ] ]
          [ HH.span
              [ classNames [ "choice-title" ] ]
              [ HH.text label ]
          ]
      ]

  networkRadio state net label =
    HH.label
      [ choiceClass (state.network == net) ]
      [ HH.input
          [ HP.type_ HP.InputRadio
          , HP.name "network"
          , HP.checked (state.network == net)
          , HE.onChange (\_ -> SelectNetwork net)
          ]
      , HH.span
          [ classNames [ "choice-title" ] ]
          [ HH.text label ]
      ]

  renderModeTabs state =
    HH.section
      [ classNames [ "panel", "input-panel" ]
      , mdSurface "input"
      ]
      [ HH.div
          [ classNames [ "panel-heading" ] ]
          [ HH.h2_ [ HH.text "Input" ]
          , HH.p_ [ HH.text "Fetch by transaction hash or paste raw CBOR hex." ]
          ]
      , HH.fieldset
          [ classNames [ "control-group" ] ]
          [ HH.legend_ [ HH.text "Mode" ]
          , HH.div
              [ classNames [ "mode-options" ] ]
              [ modeRadio state ByHash "Tx hash"
              , modeRadio state ByHex  "CBOR hex"
              ]
          ]
      , renderBody state
      ]

  modeRadio state mode label =
    HH.label
      [ choiceClass (state.mode == mode) ]
      [ HH.input
          [ HP.type_ HP.InputRadio
          , HP.name "mode"
          , HP.checked (state.mode == mode)
          , HE.onChange (\_ -> SelectMode mode)
          ]
      , HH.span
          [ classNames [ "choice-title" ] ]
          [ HH.text label ]
      ]

  renderBody state = case state.mode of
    ByHash ->
      HH.div
        [ classNames [ "decode-form", "hash-form" ] ]
        [ HH.input
            [ HP.type_ HP.InputText
            , HP.placeholder "64-char tx hash"
            , HP.value state.txHash
            , HE.onValueInput SetTxHash
            ]
        , HH.button
            [ HP.disabled state.running
            , classNames [ "primary-action" ]
            , mdControl "primary"
            , HE.onClick (\_ -> Decode)
            ]
            [ HH.text (if state.running then "Fetching..." else "Fetch and decode") ]
        ]
    ByHex ->
      HH.div
        [ classNames [ "decode-form" ] ]
        [ HH.textarea
            [ HP.value state.txHex
            , HP.placeholder "Conway tx CBOR hex..."
            , HP.rows 9
            , HE.onValueInput SetTxHex
            ]
        , HH.button
            [ HP.disabled state.running
            , classNames [ "primary-action" ]
            , mdControl "primary"
            , HE.onClick (\_ -> Decode)
            ]
            [ HH.text (if state.running then "Decoding..." else "Decode") ]
        ]

  renderResult state =
    case state.fetchError of
      Just err ->
        HH.section
          [ classNames [ "panel", "result-panel", "error-panel" ]
          , mdSurface "result"
          ]
          [ HH.div
              [ classNames [ "panel-heading" ] ]
              [ HH.h2_ [ HH.text "Fetch error" ] ]
          , HH.p_ [ HH.text err ]
          ]
      Nothing -> case state.result of
        Nothing ->
          HH.section
            [ classNames [ "panel", "result-panel", "empty-result" ]
            , mdSurface "result"
            ]
            [ HH.div
                [ classNames [ "panel-heading" ] ]
                [ HH.h2_ [ HH.text "Decoded JSON" ] ]
            , HH.div
                [ classNames [ "empty-state" ] ]
                [ HH.text "No result yet." ]
            ]
        Just r ->
          let
            summary = Json.inspect r.stdout
          in
            HH.section
              [ classNames [ "panel", "result-panel" ]
              , mdSurface "result"
              ]
              ( [ HH.div
                    [ classNames [ "panel-heading", "result-heading" ] ]
                    [ HH.div_
                        [ HH.h2_ [ HH.text (if r.exitOk then "Inspection" else "Error") ]
                        , if r.exitOk && summary.valid
                            then HH.p_ [ HH.text summary.title ]
                            else HH.text ""
                        ]
                    , if r.exitOk
                        then
                          HH.button
                            [ HE.onClick (\_ -> Copy)
                            , classNames [ "secondary-action" ]
                            , mdControl "secondary"
                            ]
                            [ HH.text (if state.copied then "Copied" else "Copy JSON") ]
                        else HH.text ""
                    ]
                ]
              <> renderIntentMaybe state
              <> ( if r.exitOk && summary.valid
                     then renderInspection summary
                     else []
                 )
              <> renderIdentificationMaybe state
              <> renderWitnessPlanMaybe state
              <> renderValidationMaybe state
              <> renderRdfMaybe state r.exitOk
              <> renderBrowserMaybe state r.exitOk
              <> [ renderRawJson r.stdout ]
              <> renderStderr r.stderr
              )

  renderIntentMaybe state =
    case state.intent of
      Just intent ->
        if intent.valid then [ renderIntentSummary state intent ]
        else []
      Nothing -> []

  renderIdentificationMaybe state =
    case state.identification of
      Just identification ->
        if identification.valid then [ renderIdentification state identification ]
        else []
      Nothing -> []

  renderWitnessPlanMaybe state =
    case state.witnessPlan of
      Just witnessPlan ->
        if witnessPlan.valid then [ renderWitnessPlan state witnessPlan ]
        else []
      Nothing -> []

  renderValidationMaybe state =
    case state.validation of
      Just validation ->
        if validation.valid then [ renderValidation state validation ]
        else []
      Nothing -> []

  renderRdfMaybe state exitOk =
    case state.rdf of
      Just rdf ->
        if exitOk && rdf.valid then
          [ renderRdfGraph rdf, renderOverlayBooks state ]
            <> renderShaclConformanceMaybe state.shaclConformance
            <> renderResolvedLabelsLensMaybe state.resolvedLabelsLens
            <> renderTypedFieldsLensMaybe state.typedFieldsLens
            <> renderSparqlLensMaybe state.sparqlLens
        else []
      Nothing -> []

  renderBrowserMaybe state exitOk =
    case state.browser of
      Just browser ->
        if exitOk && browser.valid then [ renderBrowser state browser ]
        else []
      Nothing -> []

  renderInspection summary =
    [ HH.div
        [ classNames [ "inspection-summary" ] ]
        [ HH.div
            [ classNames [ "metric-grid" ] ]
            (map renderMetric summary.metrics)
        ]
    ]

  renderIntentSummary state intent =
    HH.div
      [ classNames [ "intent-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text intent.title ]
              , HH.p_ [ HH.text intent.subtitle ]
              ]
          ]
      , HH.div
          [ classNames [ "metric-grid", "intent-metrics" ] ]
          (map renderMetric intent.metrics)
      , renderIntentClaims intent.claims
      , renderWitnessWarnings intent.warnings
      , HH.div_
          (map (renderIntentSection state) intent.sections)
      ]

  renderIntentClaims claims =
    if Array.null claims then
      HH.text ""
    else
      HH.div
        [ classNames [ "intent-claims" ] ]
        (map renderIntentClaim claims)

  renderIntentClaim claim =
    HH.div
      [ classNames [ "intent-claim" ] ]
      [ HH.span
          [ classNames [ "identity-section-title" ] ]
          [ HH.text claim.label ]
      , HH.strong_ [ HH.text claim.value ]
      , if claim.detail == "" then
          HH.text ""
        else
          HH.p_ [ HH.text claim.detail ]
      ]

  renderIntentSection state section =
    HH.div
      [ classNames [ "witness-section" ] ]
      [ HH.div
          [ classNames [ "identity-section-title" ] ]
          [ HH.text section.title ]
      , if Array.null section.rows then
          HH.div
            [ classNames [ "witness-empty" ] ]
            [ HH.text section.empty ]
        else
          HH.div
            [ classNames [ "witness-row-list" ] ]
            (map (renderWitnessRowWithCopy state false) section.rows)
      ]

  renderIdentification state identification =
    HH.div
      [ classNames [ "identity-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text identification.title ]
              , HH.p_ [ HH.text identification.subtitle ]
              ]
          ]
      , HH.div
          [ classNames [ "identity-grid" ] ]
          (map (renderIdentityRow state) identification.primary)
      , HH.div
          [ classNames [ "identity-section-title" ] ]
          [ HH.text "Witnesses" ]
      , HH.div
          [ classNames [ "witness-grid" ] ]
          (map (renderIdentityRow state) identification.witnesses)
      ]

  renderWitnessPlan state witnessPlan =
    HH.div
      [ classNames [ "identity-panel", "witness-plan" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text witnessPlan.title ]
              , HH.p_ [ HH.text witnessPlan.subtitle ]
              ]
          ]
      , HH.div
          [ classNames [ "metric-grid" ] ]
          (map renderMetric witnessPlan.metrics)
      , renderWitnessWarnings witnessPlan.warnings
      , HH.div_
          (map (renderWitnessSection state) witnessPlan.sections)
      ]

  renderValidation state validation =
    HH.div
      [ classNames [ "identity-panel", "validation-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text validation.title ]
              , HH.p_ [ HH.text validation.subtitle ]
              ]
          ]
      , HH.div
          [ classNames [ "metric-grid" ] ]
          (map renderMetric validation.metrics)
      , renderWitnessWarnings validation.warnings
      , HH.div_
          (map (renderValidationSection state) validation.sections)
      ]

  renderRdfGraph rdf =
    HH.div
      [ classNames [ "rdf-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text "Transaction RDF graph" ]
              , HH.p_ [ HH.text "Transaction graph serialized as Turtle." ]
              ]
          ]
      , HH.div
          [ classNames [ "rdf-meta" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Format" ]
          , HH.code_ [ HH.text rdf.format ]
          ]
      , HH.pre
          [ classNames [ "rdf-turtle" ] ]
          [ HH.text rdf.turtle ]
      ]

  renderOverlayBooks state =
    HH.div
      [ classNames [ "overlay-book-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text "Overlay books" ]
              , HH.p_ [ HH.text "Import optional RDF overlay or blueprint parts." ]
              ]
          ]
      , HH.div
          [ classNames [ "overlay-import-grid" ] ]
          [ HH.label
              [ classNames [ "field-stack" ] ]
              [ HH.span
                  [ classNames [ "field-label" ] ]
                  [ HH.text "Overlay Turtle or Amaru journal JSON" ]
              , HH.textarea
                  [ HP.value state.overlayInput
                  , HP.rows 8
                  , HH.attr (HH.AttrName "aria-label") "Overlay Turtle or Amaru journal JSON"
                  , HE.onValueInput SetOverlayInput
                  ]
              ]
          , HH.div
              [ classNames [ "overlay-actions" ] ]
              [ HH.button
                  [ classNames [ "secondary-action" ]
                  , mdControl "secondary"
                  , HE.onClick (\_ -> LoadAmaruOverlayBook)
                  ]
                  [ HH.text "Load Amaru overlay book" ]
              , HH.button
                  [ classNames [ "secondary-action" ]
                  , mdControl "secondary"
                  , HE.onClick (\_ -> LoadSundaeSwapBlueprintBook)
                  ]
                  [ HH.text "Load SundaeSwap V3 blueprint" ]
              , HH.button
                  [ classNames [ "secondary-action" ]
                  , mdControl "secondary"
                  , HE.onClick (\_ -> LoadShaclShapesBook)
                  ]
                  [ HH.text "Load Cardano RDF SHACL shapes" ]
              , HH.button
                  [ classNames [ "primary-action" ]
                  , mdControl "primary"
                  , HE.onClick (\_ -> ImportOverlayBook)
                  ]
                  [ HH.text "Import overlay book" ]
              , HH.button
                  [ classNames [ "primary-action" ]
                  , mdControl "primary"
                  , HE.onClick (\_ -> ApplySelectedBooks)
                  ]
                  [ HH.text "Apply selected books" ]
              ]
          ]
      , case state.overlayError of
          Just err ->
            HH.div
              [ classNames [ "sparql-lens-error" ] ]
              [ HH.text ("Overlay import failed: " <> err) ]
          Nothing -> HH.text ""
      , HH.div
          [ classNames [ "overlay-selection-grid" ] ]
          [ HH.div
              [ classNames [ "overlay-part-list" ] ]
              (renderOverlayPartList state)
          , HH.label
              [ classNames [ "field-stack" ] ]
              [ HH.span
                  [ classNames [ "field-label" ] ]
                  [ HH.text "Selected overlay Turtle" ]
              , HH.textarea
                  [ HP.value (selectedOverlayTurtle state)
                  , HP.rows 10
                  , HH.attr (HH.AttrName "aria-label") "Selected overlay Turtle"
                  , HH.attr (HH.AttrName "readonly") "readonly"
                  ]
              ]
          ]
      ]

  renderOverlayPartList state =
    if Array.null state.overlayParts then
      [ HH.div
          [ classNames [ "witness-empty" ] ]
          [ HH.text "No overlay parts imported." ]
      ]
    else
      map (renderOverlayPart state) state.overlayParts

  renderOverlayPart state part =
    let
      selected = Array.elem part.id state.selectedOverlayPartIds
    in
      HH.label
        [ choiceClass selected ]
        [ HH.input
            [ HP.type_ HP.InputCheckbox
            , HP.checked selected
            , HE.onChecked (ToggleOverlayPart part.id)
            ]
        , HH.span
            [ classNames [ "choice-title" ] ]
            [ HH.text part.label ]
        ]

  selectedOverlayTurtle state =
    String.joinWith "\n" (map _.turtle (selectedOverlayParts state))

  mergedRdfTurtle transactionGraphTurtle overlayTurtle =
    transactionGraphTurtle <> overlayTurtle

  selectedOverlayParts state =
    Array.filter
      (\part -> part.kind == "overlay" && Array.elem part.id state.selectedOverlayPartIds)
      state.overlayParts

  selectedBlueprintParts state =
    Array.filter
      (\part -> part.kind == "blueprint" && Array.elem part.id state.selectedOverlayPartIds)
      state.overlayParts

  selectedShaclParts state =
    Array.filter
      (\part -> part.kind == "shacl" && Array.elem part.id state.selectedOverlayPartIds)
      state.overlayParts

  selectedShaclTurtle state =
    String.joinWith "\n" (map _.turtle (selectedShaclParts state))

  selectedShaclLabels state =
    map _.label (selectedShaclParts state)

  selectedBlueprintArgs state =
    OverlayBook.blueprintArgs (selectedBlueprintParts state)

  renderShaclConformanceMaybe conformance =
    case conformance of
      Just value -> [ renderShaclConformance value ]
      Nothing -> []

  renderShaclConformance conformance =
    HH.div
      [ classNames [ "shacl-conformance-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text "RDF SHACL conformance" ]
              , HH.p_ [ HH.text "Selected SHACL shapes validate the composed RDF graph." ]
              ]
          ]
      , HH.div
          [ classNames [ "witness-section" ] ]
          [ HH.div
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Selected shapes" ]
          , HH.div
              [ classNames [ "witness-row-list" ] ]
              (map renderSelectedShape conformance.shapeLabels)
          ]
      , case conformance.error of
          Just err ->
            HH.div
              [ classNames [ "sparql-lens-error" ] ]
              [ HH.text ("SHACL validation failed: " <> err) ]
          Nothing ->
            case conformance.report of
              Just report ->
                HH.div_
                  [ HH.div
                      [ classNames [ "metric-grid" ] ]
                      [ renderMetric
                          { label: "Author gate"
                          , value: if report.conforms then "pass" else "fail"
                          }
                      , renderMetric
                          { label: "Auditor classifier"
                          , value:
                              if report.conforms then
                                "canonical-pipeline match"
                              else
                                "foreign/off-spec"
                          }
                      ]
                  , renderShaclViolations report
                  ]
              Nothing ->
                HH.div
                  [ classNames [ "witness-empty" ] ]
                  [ HH.text "No SHACL report." ]
      ]

  renderSelectedShape label =
    HH.div
      [ classNames [ "identity-row", "witness-row" ] ]
      [ HH.span
          [ classNames [ "identity-label" ] ]
          [ HH.text "Shape book" ]
      , HH.code_ [ HH.text label ]
      ]

  renderShaclViolations report =
    if Array.null report.violations then
      HH.div
        [ classNames [ "witness-empty" ] ]
        [ HH.text "No SHACL violations." ]
    else
      HH.div
        [ classNames [ "witness-section" ] ]
        [ HH.div
            [ classNames [ "identity-section-title" ] ]
            [ HH.text "SHACL violations" ]
        , HH.div
            [ classNames [ "sparql-lens-row-list" ] ]
            (map renderShaclViolationRow report.violations)
        ]

  renderShaclViolationRow violation =
    HH.div
      [ classNames [ "sparql-lens-row", "shacl-violation-row" ] ]
      [ renderShaclViolationCell "Focus node" violation.focusNode
      , renderShaclViolationCell "Path" violation.path
      , renderShaclViolationCell "Source shape" violation.sourceShape
      , renderShaclViolationCell "Message" violation.message
      , renderShaclViolationCell "Constraint" violation.sourceConstraintComponent
      , renderShaclViolationCell "Severity" violation.severity
      ]

  renderShaclViolationCell label value =
    HH.div
      [ classNames [ "sparql-lens-cell" ] ]
      [ HH.span
          [ classNames [ "identity-section-title" ] ]
          [ HH.text label ]
      , HH.code_ [ HH.text value ]
      ]

  renderResolvedLabelsLensMaybe lens =
    case lens of
      Just value -> [ renderResolvedLabelsLens value ]
      Nothing -> []

  renderResolvedLabelsLens lens =
    HH.div
      [ classNames [ "resolved-labels-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text "SPARQL lens: resolved labels" ]
              , HH.p_ [ HH.text "Fixed query over the transaction RDF graph plus selected overlays." ]
              ]
          ]
      , case lens.error of
          Just err ->
            HH.div
              [ classNames [ "sparql-lens-error" ] ]
              [ HH.text ("Resolved-labels query failed: " <> err) ]
          Nothing ->
            if Array.null lens.rows then
              HH.div
                [ classNames [ "witness-empty" ] ]
                [ HH.text "No resolved labels." ]
            else
              HH.div
                [ classNames [ "sparql-lens-row-list" ] ]
                (map renderResolvedLabelsRow lens.rows)
      ]

  renderResolvedLabelsRow row =
    HH.div
      [ classNames [ "sparql-lens-row", "resolved-labels-row" ] ]
      [ HH.div
          [ classNames [ "sparql-lens-cell" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Label" ]
          , HH.strong_ [ HH.text row.label ]
          ]
      , HH.div
          [ classNames [ "sparql-lens-cell" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Role" ]
          , HH.code_ [ HH.text row.role ]
          ]
      , HH.div
          [ classNames [ "sparql-lens-cell" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Entity" ]
          , HH.code_ [ HH.text row.entity ]
          ]
      , HH.div
          [ classNames [ "sparql-lens-cell" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Matched" ]
          , HH.code_ [ HH.text row.matched ]
          ]
      ]

  renderTypedFieldsLensMaybe lens =
    case lens of
      Just value -> [ renderTypedFieldsLens value ]
      Nothing -> []

  renderTypedFieldsLens lens =
    HH.div
      [ classNames [ "sparql-lens-panel", "typed-fields-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text "SPARQL lens: typed contract fields" ]
              , HH.p_ [ HH.text "Fixed query over decoded blueprint predicates." ]
              ]
          ]
      , case lens.error of
          Just err ->
            HH.div
              [ classNames [ "sparql-lens-error" ] ]
              [ HH.text ("Typed-fields query failed: " <> err) ]
          Nothing ->
            if Array.null lens.rows then
              HH.div
                [ classNames [ "witness-empty" ] ]
                [ HH.text "No typed contract fields." ]
            else
              HH.div
                [ classNames [ "sparql-lens-row-list" ] ]
                (map renderTypedFieldRow lens.rows)
      ]

  renderTypedFieldRow row =
    HH.div
      [ classNames [ "sparql-lens-row" ] ]
      [ HH.div
          [ classNames [ "sparql-lens-cell" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Subject" ]
          , HH.code_ [ HH.text row.subject ]
          ]
      , HH.div
          [ classNames [ "sparql-lens-cell" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Field" ]
          , HH.strong_ [ HH.text row.field ]
          ]
      , HH.div
          [ classNames [ "sparql-lens-cell", "sparql-lens-count" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Value" ]
          , HH.strong_ [ HH.text row.value ]
          ]
      ]

  renderSparqlLensMaybe lens =
    case lens of
      Just value -> [ renderSparqlLens value ]
      Nothing -> []

  renderSparqlLens lens =
    HH.div
      [ classNames [ "sparql-lens-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text "SPARQL lens: transaction outputs" ]
              , HH.p_ [ HH.text "Fixed query over the transaction RDF graph." ]
              ]
          ]
      , case lens.error of
          Just err ->
            HH.div
              [ classNames [ "sparql-lens-error" ] ]
              [ HH.text ("SPARQL query failed: " <> err) ]
          Nothing ->
            if Array.null lens.rows then
              HH.div
                [ classNames [ "witness-empty" ] ]
                [ HH.text "No rows." ]
            else
              HH.div
                [ classNames [ "sparql-lens-row-list" ] ]
                (map renderSparqlLensRow lens.rows)
      ]

  renderSparqlLensRow row =
    HH.div
      [ classNames [ "sparql-lens-row" ] ]
      [ HH.div
          [ classNames [ "sparql-lens-cell" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Transaction" ]
          , HH.code_ [ HH.text row.transaction ]
          ]
      , HH.div
          [ classNames [ "sparql-lens-cell" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Tx id" ]
          , HH.code_ [ HH.text row.txId ]
          ]
      , HH.div
          [ classNames [ "sparql-lens-cell", "sparql-lens-count" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Outputs" ]
          , HH.strong_ [ HH.text row.outputs ]
          ]
      ]

  renderValidationSection state section =
    HH.div
      [ classNames [ "witness-section" ] ]
      [ HH.div
          [ classNames [ "identity-section-title" ] ]
          [ HH.text section.title ]
      , if Array.null section.rows then
          HH.div
            [ classNames [ "witness-empty" ] ]
            [ HH.text section.empty ]
        else
          HH.div
            [ classNames [ "witness-row-list" ] ]
            (map (renderValidationRow state section.title) section.rows)
      ]

  renderValidationRow state sectionTitle row =
    let
      presented = presentValidationRow sectionTitle row
    in
      renderWitnessRowWithCopy state (validationRowCanCopy sectionTitle presented) presented

  validationRowCanCopy sectionTitle row =
    case sectionTitle of
      "Checks" -> false
      "Missing context" -> StringCodeUnits.length row.copyValue == 64
      _ -> true

  presentValidationRow sectionTitle row =
    case sectionTitle of
      "Checks" ->
        row
          { value = presentValidationCheckStatus row.value row.detail
          , detail = presentValidationCheckDetail row.detail
          }
      "Missing context" ->
        row { label = readableValidationToken row.label }
      _ -> row

  presentValidationCheckStatus status detail =
    if status == "not_evaluated" && validationCheckNeedsContext detail then
      "needs context"
    else
      readableValidationToken status

  validationCheckNeedsContext detail =
    StringCodeUnits.contains (String.Pattern "needs more explicit context") detail
      || StringCodeUnits.contains (String.Pattern "Missing ") detail

  presentValidationCheckDetail detail =
    if StringCodeUnits.contains (String.Pattern "scope ledger / Ledger validation needs more explicit context before Conway applyTx can run.") detail then
      "Missing required validation context."
    else if StringCodeUnits.contains (String.Pattern "scope ledger / Ledger validation was not run because the supplied context is invalid.") detail then
      "Fix the context errors below."
    else
      stripValidationScope detail

  stripValidationScope detail =
    String.replaceAll (String.Pattern "scope ledger / ") (String.Replacement "")
      (String.replaceAll (String.Pattern "scope context / ") (String.Replacement "") detail)

  readableValidationToken token =
    String.replaceAll (String.Pattern "_") (String.Replacement " ") token

  renderWitnessWarnings warnings =
    if Array.null warnings then
      HH.text ""
    else
      HH.div
        [ classNames [ "witness-warnings" ] ]
        (map (\warning -> HH.p_ [ HH.text warning ]) warnings)

  renderWitnessSection state section =
    HH.div
      [ classNames [ "witness-section" ] ]
      [ HH.div
          [ classNames [ "identity-section-title" ] ]
          [ HH.text section.title ]
      , if Array.null section.rows then
          HH.div
            [ classNames [ "witness-empty" ] ]
            [ HH.text section.empty ]
        else
          HH.div
            [ classNames [ "witness-row-list" ] ]
            (map (renderWitnessRow state) section.rows)
      ]

  renderWitnessRow state row =
    renderWitnessRowWithCopy state true row

  renderWitnessRowWithCopy state showCopy row =
    HH.div
      [ classNames [ "identity-row", "witness-row" ] ]
      [ HH.div
          [ classNames [ "identity-copy" ] ]
          [ HH.span
              [ classNames [ "identity-label" ] ]
              [ HH.text row.label ]
          , if showCopy then
              HH.button
                [ HE.onClick (\_ -> CopyValue row.path row.copyValue)
                , classNames [ "inline-action" ]
                , mdControl "inline"
                ]
                [ HH.text
                    ( if state.copiedPath == Just row.path then
                        "Copied"
                      else
                        "Copy"
                    )
                ]
            else
              HH.text ""
          ]
      , HH.code_ [ HH.text row.value ]
      , if row.detail == "" then
          HH.text ""
        else
          HH.span
            [ classNames [ "witness-detail" ] ]
            [ HH.text row.detail ]
      ]

  renderIdentityRow state row =
    let
      canCopy = identityRowCanCopy row.path
      copied = state.copiedPath == Just row.path
      rowClasses =
        if copied then [ "identity-row", "is-copied" ]
        else [ "identity-row" ]
      valueClasses =
        if canCopy then [ "identity-value", "summary-copy-target" ]
        else [ "identity-value" ]
      valueProps =
        if canCopy then
          [ classNames valueClasses
          , HE.onClick (\_ -> CopyValue row.path row.copyValue)
          , HP.title "Copy value"
          ]
        else
          [ classNames valueClasses ]
    in
    HH.div
      [ classNames rowClasses ]
      [ HH.span
          [ classNames [ "identity-label" ] ]
          [ HH.text row.label ]
      , HH.code valueProps [ HH.text row.value ]
      ]

  identityRowCanCopy path =
    path == "[\"identification\",\"tx_id\"]"
      || path == "[\"identification\",\"body_hash\"]"

  renderBrowser state browser =
    HH.div
      [ classNames [ "json-browser" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "browser-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text "Transaction browser" ]
              , HH.p_ [ HH.text browser.subtitle ]
              ]
          , HH.button
              [ HE.onClick (\_ -> CopyValue browser.currentPath browser.currentJson)
              , classNames [ "inline-action" ]
              , mdControl "inline"
              ]
              [ HH.text
                  ( if state.copiedPath == Just browser.currentPath then
                      "Copied"
                    else
                      "Copy current"
                  )
              ]
          ]
      , HH.div
          [ classNames [ "browser-row-list" ] ]
          (renderTreeRows state browser)
      ]

  renderTreeRows state browser =
    if Array.null browser.rows then
      [ HH.div
          [ classNames [ "scalar-value" ] ]
          [ HH.code_ [ HH.text browser.currentJson ] ]
      ]
    else
      Array.concatMap (renderTreeRow state) browser.rows

  renderTreeRow state row =
    let
      expanded = isExpanded row.path state.expandedPaths
      child = browserAt row.path state.browserNodes
      copied = state.copiedPath == Just row.path
    in
      [ HH.div
          [ classNames
              ( if expanded then
                  if copied then [ "browser-row", "is-expanded", "is-copied" ]
                  else [ "browser-row", "is-expanded" ]
                else
                  if copied then [ "browser-row", "is-copied" ]
                  else [ "browser-row" ]
              )
          ]
          [ HH.div
              [ classNames [ "browser-row-main" ] ]
              [ HH.div
                  [ classNames [ "browser-keyline" ] ]
                  [ HH.code_ [ HH.text row.label ]
                  , HH.span
                      [ classNames [ "kind-badge" ] ]
                      [ HH.text row.kind ]
                  ]
              , HH.div
                  [ classNames [ "browser-summary", "summary-copy-target" ]
                  , HE.onClick (\_ -> CopyValue row.path row.copyValue)
                  , HP.title "Copy value"
                  ]
                  [ HH.text row.summary ]
              ]
          , if row.canDive then
              HH.div
                [ classNames [ "browser-actions" ] ]
                [
                  HH.button
                    [ HE.onClick (\_ -> BrowseJson row.path)
                    , classNames [ "inline-action" ]
                    , mdControl "inline"
                    ]
                    [ HH.text (if expanded then "Close" else "Open") ]
                ]
            else HH.text ""
          ]
      ] <> if expanded then
        [ HH.div
            [ classNames [ "browser-children" ] ]
            ( case child of
                Just browser ->
                  renderTreeRows state browser
                Nothing ->
                  [ HH.div
                      [ classNames [ "scalar-value" ] ]
                      [ HH.code_ [ HH.text "Loading..." ] ]
                  ]
            )
        ]
      else []

  isExpanded path paths =
    Array.elem path paths

  browserAt path nodes =
    _.browser <$> Array.find (\node -> node.path == path) nodes

  upsertBrowserNode path browser nodes =
    if Array.any (\node -> node.path == path) nodes then
      map
        ( \node ->
            if node.path == path then
              { path, browser }
            else
              node
        )
        nodes
    else
      Array.snoc nodes { path, browser }

  expandPath path paths =
    if Array.elem path paths then paths
    else Array.snoc paths path

  closePath path paths =
    Array.filter (_ /= path) paths

  rootBrowserNodes browser =
    [ { path: browser.currentPath, browser } ]

  renderMetric metric =
    HH.div
      [ classNames [ "metric-card" ] ]
      [ HH.span
          [ classNames [ "metric-label" ] ]
          [ HH.text metric.label ]
      , HH.strong_ [ HH.text metric.value ]
      ]

  renderRawJson stdout =
    HH.details
      [ classNames [ "raw-json-block" ] ]
      [ HH.summary_ [ HH.text "Raw JSON" ]
      , HH.pre_ [ HH.text (Json.pretty stdout) ]
      ]

  renderStderr stderr =
    if stderr == "" then []
    else
      [ HH.div
          [ classNames [ "stderr-block" ] ]
          [ HH.h3_ [ HH.text "stderr" ]
          , HH.pre_ [ HH.text stderr ]
          ]
      ]

  classNames :: forall r a. Array String -> HP.IProp (class :: String | r) a
  classNames names = HP.classes (map HH.ClassName names)

  mdSurface :: forall r a. String -> HP.IProp r a
  mdSurface = HH.attr (HH.AttrName "data-md3-surface")

  mdControl :: forall r a. String -> HP.IProp r a
  mdControl = HH.attr (HH.AttrName "data-md3-control")

  choiceClass :: forall r a. Boolean -> HP.IProp (class :: String | r) a
  choiceClass selected =
    classNames
      ( if selected then
          [ "choice-option", "is-selected" ]
        else
          [ "choice-option" ]
      )

  looksLikeBlockfrostProjectId value =
    let
      trimmed = String.trim value
    in
      StringCodeUnits.take 7 trimmed == "mainnet"
        || StringCodeUnits.take 7 trimmed == "preprod"
        || StringCodeUnits.take 7 trimmed == "preview"

  resolvedLabelsLensFromGraph graphTurtle = do
    lensResult <- liftEffect (RdfShapes.queryResolvedLabels graphTurtle)
    pure
      ( Just
          ( case lensResult of
              Left err ->
                { rows: []
                , error: Just err
                }
              Right rows ->
                { rows
                , error: Nothing
                }
          )
      )

  sparqlLensFromGraph graphTurtle = do
    lensResult <- liftEffect (RdfShapes.queryTransactionOutputs graphTurtle)
    pure
      ( Just
          ( case lensResult of
              Left err ->
                { rows: []
                , error: Just err
                }
              Right rows ->
                { rows
                , error: Nothing
                }
          )
      )

  typedFieldsLensFromGraph graphTurtle = do
    lensResult <- liftEffect (RdfShapes.queryTypedFields graphTurtle)
    pure
      ( Just
          ( case lensResult of
              Left err ->
                { rows: []
                , error: Just err
                }
              Right rows ->
                { rows
                , error: Nothing
              }
          )
      )

  shaclConformanceFromGraph graphTurtle st =
    let
      shapeParts = selectedShaclParts st
    in
      if Array.null shapeParts then
        pure Nothing
      else do
        reportResult <- liftEffect (RdfShapes.validate graphTurtle (selectedShaclTurtle st))
        pure
          ( Just
              { shapeLabels: selectedShaclLabels st
              , report:
                  case reportResult of
                    Right report -> Just report
                    Left _       -> Nothing
              , error:
                  case reportResult of
                    Right _  -> Nothing
                    Left err -> Just err
              }
          )

  rdfLensesForState st rdf = do
    sparqlLens <- sparqlLensFromGraph rdf.turtle
    let graphTurtle = mergedRdfTurtle rdf.turtle (selectedOverlayTurtle st)
    resolvedLabelsLens <-
      resolvedLabelsLensFromGraph graphTurtle
    typedFieldsLens <- typedFieldsLensFromGraph rdf.turtle
    shaclConformance <- shaclConformanceFromGraph graphTurtle st
    pure
      { sparqlLens
      , resolvedLabelsLens
      , typedFieldsLens
      , shaclConformance
      }

  resolvedLabelsLensForState st =
    case st.rdf of
      Just rdf ->
        if rdf.valid then
          resolvedLabelsLensFromGraph
            (mergedRdfTurtle rdf.turtle (selectedOverlayTurtle st))
        else
          pure Nothing
      Nothing -> pure Nothing

  shaclConformanceForState st =
    case st.rdf of
      Just rdf ->
        if rdf.valid then
          shaclConformanceFromGraph
            (mergedRdfTurtle rdf.turtle (selectedOverlayTurtle st))
            st
        else
          pure Nothing
      Nothing -> pure Nothing

  handleAction = case _ of
    Navigate route event -> do
      routeBase <- H.gets _.routeBase
      liftEffect do
        Event.preventDefault (MouseEvent.toEvent event)
        Routing.pushRoute routeBase route
      H.modify_ _ { route = route }
    ToggleTheme -> do
      theme <- H.gets _.theme
      nextTheme <- liftEffect (Shell.toggleThemeEff theme)
      H.modify_ _ { theme = nextTheme }
    SetBlockfrostKey s -> do
      H.modify_ _ { blockfrostKey = s }
      persist <- H.gets _.persistKeys
      when persist (liftEffect (Storage.setItem blockfrostKey s))
    SetKoiosBearer s -> do
      if looksLikeBlockfrostProjectId s then do
        H.modify_ _ { provider = Blockfrost, blockfrostKey = s, fetchError = Nothing }
        liftEffect (Storage.setItem providerKey (Provider.providerName Blockfrost))
        persist <- H.gets _.persistKeys
        when persist (liftEffect (Storage.setItem blockfrostKey s))
      else do
        H.modify_ _ { koiosBearer = s }
        persist <- H.gets _.persistKeys
        when persist (liftEffect (Storage.setItem koiosKey s))
    SelectProvider p -> do
      H.modify_ _ { provider = p, fetchError = Nothing }
      liftEffect (Storage.setItem providerKey (Provider.providerName p))
    TogglePersist on -> do
      H.modify_ _ { persistKeys = on }
      liftEffect (Storage.setItem persistKeysStorageKey (if on then "true" else "false"))
      st <- H.get
      liftEffect
        if on
          then do
            Storage.setItem blockfrostKey st.blockfrostKey
            Storage.setItem koiosKey st.koiosBearer
          else do
            Storage.setItem blockfrostKey ""
            Storage.setItem koiosKey ""
    SelectMode m -> H.modify_ _ { mode = m, fetchError = Nothing, copiedPath = Nothing }
    SelectNetwork n -> do
      H.modify_ _ { network = n, fetchError = Nothing, copiedPath = Nothing }
      liftEffect (Storage.setItem networkKey (networkName n))
    SetTxHash s -> H.modify_ _ { txHash = s, copied = false, copiedPath = Nothing, fetchError = Nothing }
    SetTxHex s -> H.modify_ _ { txHex = s, copied = false, copiedPath = Nothing, fetchError = Nothing }
    SetOverlayInput s -> H.modify_ _ { overlayInput = s, overlayError = Nothing }
    ImportOverlayBook -> do
      input <- H.gets _.overlayInput
      parsed <- liftEffect (OverlayBook.parse input)
      case parsed of
        Left err ->
          H.modify_ _ { overlayError = Just err }
        Right book -> do
          st <- H.get
          let nextState = st { overlayParts = book.parts, selectedOverlayPartIds = [] }
          resolvedLabelsLens <- resolvedLabelsLensForState nextState
          shaclConformance <- shaclConformanceForState nextState
          H.modify_
            _
              { overlayParts = book.parts
              , selectedOverlayPartIds = []
              , overlayError = Nothing
              , resolvedLabelsLens = resolvedLabelsLens
              , shaclConformance = shaclConformance
              }
    LoadAmaruOverlayBook -> do
      let input = OverlayBook.bundledAmaruJournal
      parsed <- liftEffect (OverlayBook.parse input)
      case parsed of
        Left err ->
          H.modify_ _ { overlayInput = input, overlayError = Just err }
        Right book -> do
          st <- H.get
          let nextState = st { overlayParts = book.parts, selectedOverlayPartIds = [] }
          resolvedLabelsLens <- resolvedLabelsLensForState nextState
          shaclConformance <- shaclConformanceForState nextState
          H.modify_
            _
              { overlayInput = input
              , overlayParts = book.parts
              , selectedOverlayPartIds = []
              , overlayError = Nothing
              , resolvedLabelsLens = resolvedLabelsLens
              , shaclConformance = shaclConformance
              }
    LoadSundaeSwapBlueprintBook -> do
      let input = OverlayBook.bundledSundaeSwapBlueprint
      parsed <- liftEffect (OverlayBook.parse input)
      case parsed of
        Left err ->
          H.modify_ _ { overlayInput = input, overlayError = Just err }
        Right book -> do
          st <- H.get
          let nextState = st { overlayParts = book.parts, selectedOverlayPartIds = [] }
          resolvedLabelsLens <- resolvedLabelsLensForState nextState
          shaclConformance <- shaclConformanceForState nextState
          H.modify_
            _
              { overlayInput = input
              , overlayParts = book.parts
              , selectedOverlayPartIds = []
              , overlayError = Nothing
              , resolvedLabelsLens = resolvedLabelsLens
              , shaclConformance = shaclConformance
              }
    LoadShaclShapesBook -> do
      st <- H.get
      let
        input = cardanoShaclShapes
        parts =
          [ { id: "cardano-rdf-shacl-shapes"
            , label: "Cardano transaction SHACL shapes"
            , kind: "shacl"
            , turtle: input
            , plutusJson: ""
            }
          ]
        nextState = st { overlayParts = parts, selectedOverlayPartIds = [] }
      resolvedLabelsLens <- resolvedLabelsLensForState nextState
      shaclConformance <- shaclConformanceForState nextState
      H.modify_
        _
          { overlayInput = input
          , overlayParts = parts
          , selectedOverlayPartIds = []
          , overlayError = Nothing
          , resolvedLabelsLens = resolvedLabelsLens
          , shaclConformance = shaclConformance
          }
    ToggleOverlayPart partId selected -> do
      st <- H.get
      let
        selectedOverlayPartIds =
          toggleOverlayPartId partId selected st.selectedOverlayPartIds
        nextState = st { selectedOverlayPartIds = selectedOverlayPartIds }
      resolvedLabelsLens <- resolvedLabelsLensForState nextState
      shaclConformance <- shaclConformanceForState nextState
      H.modify_
        _
          { selectedOverlayPartIds = selectedOverlayPartIds
          , resolvedLabelsLens = resolvedLabelsLens
          , shaclConformance = shaclConformance
          }
    ApplySelectedBooks -> do
      st <- H.get
      case st.txCbor of
        Nothing -> do
          resolvedLabelsLens <- resolvedLabelsLensForState st
          shaclConformance <- shaclConformanceForState st
          H.modify_
            _
              { resolvedLabelsLens = resolvedLabelsLens
              , shaclConformance = shaclConformance
              , overlayError = Nothing
              }
        Just txCbor -> do
          H.modify_ _ { running = true, fetchError = Nothing, overlayError = Nothing }
          let rdfArgs = Json.operationArgsMerged st.operationArgs (selectedBlueprintArgs st)
          rdfResult <- H.liftAff (runLedgerOperation txCbor "tx.rdf" rdfArgs)
          let rdf = Json.operationRdfGraph rdfResult.stdout
          if rdfResult.exitOk && rdf.valid then do
            lenses <- rdfLensesForState st rdf
            H.modify_
              _
                { running = false
                , rdf = Just rdf
                , sparqlLens = lenses.sparqlLens
                , resolvedLabelsLens = lenses.resolvedLabelsLens
                , typedFieldsLens = lenses.typedFieldsLens
                , shaclConformance = lenses.shaclConformance
                , fetchError = Nothing
                }
          else
            H.modify_
              _
                { running = false
                , rdf = Nothing
                , sparqlLens = Nothing
                , resolvedLabelsLens = Nothing
                , typedFieldsLens = Nothing
                , shaclConformance = Nothing
                , fetchError =
                    Just
                      ( if rdfResult.stderr == "" then
                          "Haskell ledger operation tx.rdf failed."
                        else
                          rdfResult.stderr
                      )
                }
    Decode -> do
      st <- H.get
      H.modify_
        _
          { running = true
          , result = Nothing
          , txCbor = Nothing
          , operationArgs = "{}"
          , browser = Nothing
          , identification = Nothing
          , intent = Nothing
          , witnessPlan = Nothing
          , validation = Nothing
          , rdf = Nothing
          , sparqlLens = Nothing
          , resolvedLabelsLens = Nothing
          , typedFieldsLens = Nothing
          , shaclConformance = Nothing
          , browserNodes = []
          , expandedPaths = []
          , copied = false
          , copiedPath = Nothing
          , browserPath = "[]"
          , fetchError = Nothing
          }
      hexE <- case st.mode of
        ByHex -> pure (Right (String.trim st.txHex))
        ByHash ->
          let key = case st.provider of
                Blockfrost -> String.trim st.blockfrostKey
                Koios      -> String.trim st.koiosBearer
              trimmedHash = String.trim st.txHash
          in
            if Provider.needsKey st.provider && key == ""
              then pure (Left (Provider.providerName st.provider <> " key not set."))
              else if trimmedHash == ""
                then pure (Left "Tx hash is empty.")
                else do
                  e <- H.liftAff (attempt (Provider.fetchTxCbor st.provider st.network key trimmedHash))
                  case e of
                    Left err ->
                      let raw = message err
                          diag = case st.provider of
                            Koios | raw == "Failed to fetch" ->
                              if String.trim st.koiosBearer == ""
                                then "Koios blocks anonymous browser requests by design. Sign up (free) at koios.rest/auth, paste the bearer token above, and retry."
                                else "Koios rejected the request. Check the bearer token is valid and the network matches (mainnet/preprod/preview)."
                            _ -> raw
                      in pure (Left diag)
                    Right cbor -> pure (Right cbor)
      case hexE of
        Left err -> H.modify_ _ { running = false, fetchError = Just err, browserPath = "[]" }
        Right h -> do
          operationResult <- H.liftAff (runLedgerOperation h "tx.inspect" "{}")
          let
            providerKeyValue = case st.provider of
              Blockfrost -> String.trim st.blockfrostKey
              Koios      -> String.trim st.koiosBearer
            canFetchProducerTxs =
              operationResult.exitOk
                && (not (Provider.needsKey st.provider) || providerKeyValue /= "")
          inputContextArgs <-
            if operationResult.exitOk then do
              ctx <- H.liftAff
                (attempt (Provider.resolveProducerTxContext st.provider st.network providerKeyValue canFetchProducerTxs operationResult.stdout))
              case ctx of
                Right args -> pure args
                Left err ->
                  pure
                    ( Json.providerResolutionErrorArgs
                        (Provider.providerName st.provider)
                        (message err)
                    )
            else pure "{}"
          identifyResult <- H.liftAff (runLedgerOperation h "tx.identify" inputContextArgs)
          intentResult <- H.liftAff (runLedgerOperation h "tx.intent" inputContextArgs)
          witnessPlanResult <- H.liftAff (runLedgerOperation h "tx.witness.plan" inputContextArgs)
          validationResult <- H.liftAff (runLedgerOperation h "tx.validate" inputContextArgs)
          let rdfArgs = Json.operationArgsMerged inputContextArgs (selectedBlueprintArgs st)
          rdfResult <- H.liftAff (runLedgerOperation h "tx.rdf" rdfArgs)
          let
            inspectionResult = operationResult { stdout = Json.operationInspection operationResult.stdout }
            browser = Json.operationBrowser operationResult.stdout
            identification = Json.operationIdentification identifyResult.stdout
            intent = Json.operationIntentSummary intentResult.stdout
            witnessPlan = Json.operationWitnessPlan witnessPlanResult.stdout
            validation = Json.operationValidation validationResult.stdout
            rdf = Json.operationRdfGraph rdfResult.stdout
          lenses <-
            if operationResult.exitOk && rdfResult.exitOk && rdf.valid then
              rdfLensesForState st rdf
            else
              pure
                { sparqlLens: Nothing
                , resolvedLabelsLens: Nothing
                , typedFieldsLens: Nothing
                , shaclConformance: Nothing
                }
          H.modify_
            _
              { running = false
              , result = Just inspectionResult
              , txCbor = Just h
              , operationArgs = inputContextArgs
              , browser = if operationResult.exitOk && browser.valid then Just browser else Nothing
              , identification =
                  if identifyResult.exitOk && identification.valid then Just identification
                  else Nothing
              , intent =
                  if intentResult.exitOk && intent.valid then Just intent
                  else Nothing
              , witnessPlan =
                  if witnessPlanResult.exitOk && witnessPlan.valid then Just witnessPlan
                  else Nothing
              , validation =
                  if validationResult.exitOk && validation.valid then Just validation
                  else Nothing
              , rdf =
                  if operationResult.exitOk && rdfResult.exitOk && rdf.valid then Just rdf
                  else Nothing
              , sparqlLens = lenses.sparqlLens
              , resolvedLabelsLens = lenses.resolvedLabelsLens
              , typedFieldsLens = lenses.typedFieldsLens
              , shaclConformance = lenses.shaclConformance
              , browserNodes =
                  if operationResult.exitOk && browser.valid then rootBrowserNodes browser
                  else []
              , expandedPaths = []
              , browserPath = browser.currentPath
              }
    Copy -> do
      mr <- H.gets _.result
      case mr of
        Nothing -> pure unit
        Just r -> do
          H.liftAff (Clipboard.copy (Json.pretty r.stdout))
          H.modify_ _ { copied = true, copiedPath = Nothing }
    CopyValue path value -> do
      H.liftAff (Clipboard.copy value)
      H.modify_ _ { copied = false, copiedPath = Just path }
    BrowseJson path ->
      do
        st <- H.get
        if isExpanded path st.expandedPaths then
          H.modify_ _ { expandedPaths = closePath path st.expandedPaths, copiedPath = Nothing }
        else case st.txCbor of
          Nothing ->
            H.modify_ _ { browserPath = path, copiedPath = Nothing }
          Just txCbor -> do
            H.modify_ _ { browserPath = path, copiedPath = Nothing }
            let args = Json.operationArgsWithPath st.operationArgs path
            operationResult <- H.liftAff (runLedgerOperation txCbor "tx.browse" args)
            let browser = Json.operationBrowser operationResult.stdout
            H.modify_
              _
                { browserNodes =
                    if operationResult.exitOk && browser.valid then
                      upsertBrowserNode path browser st.browserNodes
                    else
                      st.browserNodes
                , expandedPaths =
                    if operationResult.exitOk && browser.valid then
                      expandPath path st.expandedPaths
                    else
                      st.expandedPaths
                , browserPath = browser.currentPath
                , fetchError =
                    if operationResult.exitOk && browser.valid then Nothing
                    else Just (if operationResult.stderr == "" then "Haskell ledger operation browse failed." else operationResult.stderr)
                }

  toggleOverlayPartId partId selected ids =
    if selected then
      if Array.elem partId ids then ids
      else Array.snoc ids partId
    else
      Array.filter (_ /= partId) ids
