module Main (main) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), Replacement(..), joinWith, replaceAll, trim) as String
import Data.String.CodeUnits as StringCodeUnits
import Effect (Effect)
import Effect.Aff (attempt)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import Examples as Examples
import FFI.Blockfrost (Network(..), networkName)
import FFI.BookStore as BookStore
import FFI.Clipboard (copy) as Clipboard
import FFI.Inspector (InspectorResult, runLedgerOperation)
import FFI.Json (Browser, Identification, IntentSummary, RdfGraph, Validation, WitnessPlan, inspect, operationArgsMerged, operationArgsWithPath, operationBrowser, operationIdentification, operationInspection, operationIntentSummary, operationRdfGraph, operationValidation, operationWitnessPlan, pretty, providerResolutionErrorArgs) as Json
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
import Rdf.Editor as RdfEditor
import Type.Proxy (Proxy(..))
import Unsafe.Coerce (unsafeCoerce)
import Web.Event.Event as Event
import Web.DOM.ParentNode (QuerySelector(..))
import Web.HTML (window)
import Web.HTML.Window as Window
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
  bookStore <- liftEffect BookStore.load
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
        , books: bookStore.books
        }
    ) unit mountTarget

data Mode = ByHash | ByHex

derive instance eqMode :: Eq Mode

data ResultTab = StructureTab | WitnessTab | ValidationTab | GraphRdfTab

derive instance eqResultTab :: Eq ResultTab

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
  , loadFormExpanded :: Boolean
  , resultTab :: ResultTab
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
  , decodedTreeLens :: Maybe DecodedTreeLens
  , shaclConformance :: Maybe ShaclConformance
  , books :: Array BookStore.Book
  , bookNameEdits :: Array BookNameEdit
  , annotationDraft :: Maybe AnnotationDraft
  , libraryInput :: String
  , libraryUrl :: String
  , libraryError :: Maybe String
  , browserNodes :: Array BrowserNode
  , expandedPaths :: Array String
  , decodedTreeExpanded :: Array String
  , decodedEmptyExpanded :: Array String
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

type DecodedTreeLens =
  { rows :: Array RdfShapes.DecodedTreeRow
  , error :: Maybe String
  }

type ShaclConformance =
  { shapeLabels :: Array String
  , report :: Maybe RdfShapes.ShaclReport
  , error :: Maybe String
  }

type BookNameEdit =
  { id :: String
  , name :: String
  }

type AnnotationDraft =
  { rowId :: String
  , label :: String
  , typeName :: String
  , mode :: String
  , bookId :: String
  , newBookName :: String
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
  , books :: Array BookStore.Book
  }

data Action
  = Initialize
  | SetBlockfrostKey String
  | SetKoiosBearer String
  | SelectProvider Provider
  | TogglePersist Boolean
  | SelectMode Mode
  | SelectNetwork Network
  | SetTxHash String
  | SetTxHex String
  | LoadExample String
  | SetLibraryInput String
  | SetLibraryUrl String
  | AddLibraryBook
  | ImportLibraryBookFile
  | ImportLibraryBookFromUrl
  | ExportSelectedLibraryBooks
  | ExportAllLibraryBooks
  | ImportLibraryStoreFile
  | ToggleLibraryBook String Boolean
  | SetLibraryBookName String String
  | SaveLibraryBookName String
  | DeleteLibraryBook String
  | CopyLibraryBookSource String
  | SaveLibraryBookSource String
  | ApplySelectedBooks
  | StartDecodedTreeAnnotation RdfShapes.DecodedTreeRow
  | SetDecodedTreeAnnotationLabel String
  | SetDecodedTreeAnnotationType String
  | SetDecodedTreeAnnotationMode String
  | SetDecodedTreeAnnotationBookId String
  | SetDecodedTreeAnnotationNewBookName String
  | CancelDecodedTreeAnnotation
  | SaveDecodedTreeAnnotation RdfShapes.DecodedTreeRow
  | Decode
  | Copy
  | CopyValue String String
  | BrowseJson String
  | ToggleDecodedEmpty String
  | ToggleDecodedTree String
  | SelectResultTab ResultTab
  | ChangeInput
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
        , loadFormExpanded: true
        , resultTab: StructureTab
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
        , decodedTreeLens: Nothing
        , shaclConformance: Nothing
        , books: initial.books
        , bookNameEdits: bookNameEditsFromBooks initial.books
        , annotationDraft: Nothing
        , libraryInput: ""
        , libraryUrl: ""
        , libraryError: Nothing
        , browserNodes: []
        , expandedPaths: []
        , decodedTreeExpanded: []
        , decodedEmptyExpanded: []
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
    , eval: H.mkEval H.defaultEval { handleAction = handleAction, initialize = Just Initialize }
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
              RouteLibrary -> renderLibrary state
          ]
      , Shell.siteFooter
      ]

  renderInspector state =
    let
      decodedLoaded = case state.result of
        Just r -> isDecodedResult r
        Nothing -> false
      showLoadedHeader = decodedLoaded && not state.loadFormExpanded
    in
      HH.div
        [ classNames [ "app-shell", "inspect-shell" ] ]
        [ HH.div
            [ classNames
                ( if showLoadedHeader then
                    [ "workspace", "loaded-workspace" ]
                  else
                    [ "workspace" ]
                )
            ]
            [ if showLoadedHeader then
                renderLoadedInspectorHeader state
              else
                renderLoadForm state
            , renderBooksPanel state showLoadedHeader
            , HH.div
                [ classNames [ "workspace-main" ] ]
                [ renderResult state ]
            ]
        ]

  isDecodedResult result =
    result.exitOk && (Json.inspect result.stdout).valid

  renderLoadForm state =
    HH.div
      [ classNames [ "load-form-stack" ] ]
      [ renderSettingsSummary state
      , renderModeTabs state
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

  renderLibrary state =
    let
      inspection = BookStore.inspect { kind: BookStore.envelopeKind, books: state.books }
    in
      HH.div
        [ classNames [ "app-shell", "library-page" ] ]
        [ HH.section
            [ classNames [ "intro-strip" ] ]
            [ HH.div_
                [ HH.h1_ [ HH.text "Library" ]
                , HH.p_
                    [ HH.text
                        "Manage local RDF overlay and blueprint books stored in this browser."
                    ]
                ]
            , HH.div
                [ classNames [ "tech-pills" ] ]
                [ HH.span_ [ HH.text (show inspection.count <> " books") ]
                , HH.span_ [ HH.text (show inspection.selectedCount <> " selected") ]
                , HH.span_ [ HH.text (show inspection.partCount <> " parts") ]
                ]
            ]
        , HH.div
            [ classNames [ "library-layout" ] ]
            [ renderLibraryImport state
            , renderLibraryBooks state
            ]
        ]

  renderLibraryImport state =
    HH.element (HH.ElemName "md-elevated-card")
      [ classNames [ "panel", "library-import-panel" ]
      , mdSurface "books"
      ]
      [ HH.div
          [ classNames [ "panel-heading" ] ]
          [ HH.div_
              [ HH.h2_ [ HH.text "Add book" ]
              , HH.p_ [ HH.text "Import overlay, blueprint, SHACL, or store JSON into this browser." ]
              ]
          ]
      , HH.label
          [ classNames [ "field-stack" ] ]
          [ HH.span
              [ classNames [ "field-label" ] ]
              [ HH.text "Book Turtle" ]
          , HH.textarea
              [ HP.value state.libraryInput
              , HP.rows 8
              , HH.attr (HH.AttrName "aria-label") "Book Turtle"
              , HE.onValueInput SetLibraryInput
              ]
          ]
      , HH.div
          [ classNames [ "library-actions" ] ]
          [ HH.element (HH.ElemName "md-filled-button")
              [ classNames [ "primary-action" ]
              , HH.attr (HH.AttrName "role") "button"
              , mdControl "primary"
              , HP.disabled (String.trim state.libraryInput == "")
              , HE.onClick (\_ -> AddLibraryBook)
              ]
              [ HH.text "Add book" ]
          , HH.element (HH.ElemName "md-outlined-button")
              [ classNames [ "secondary-action" ]
              , HH.attr (HH.AttrName "role") "button"
              , mdControl "secondary"
              , HP.disabled
                  ( Array.null
                      ( BookStore.selectedBooks
                          { kind: BookStore.envelopeKind, books: state.books }
                      )
                  )
              , HE.onClick (\_ -> ExportSelectedLibraryBooks)
              ]
              [ HH.text "Export selected books" ]
          , HH.element (HH.ElemName "md-outlined-button")
              [ classNames [ "secondary-action" ]
              , HH.attr (HH.AttrName "role") "button"
              , mdControl "secondary"
              , HP.disabled (Array.null state.books)
              , HE.onClick (\_ -> ExportAllLibraryBooks)
              ]
              [ HH.text "Export all books" ]
          ]
      , HH.div
          [ classNames [ "library-exchange-grid" ] ]
          [ HH.div
              [ classNames [ "library-url-row" ] ]
              [ HH.label
                  [ classNames [ "field-stack", "library-url-field" ] ]
                  [ HH.span
                      [ classNames [ "field-label" ] ]
                      [ HH.text "Book URL" ]
                  , HH.input
                      [ HP.type_ HP.InputText
                      , HP.value state.libraryUrl
                      , HH.attr (HH.AttrName "aria-label") "Book URL"
                      , HE.onValueInput SetLibraryUrl
                      ]
                  ]
              , HH.element (HH.ElemName "md-outlined-button")
                  [ classNames [ "secondary-action" ]
                  , HH.attr (HH.AttrName "role") "button"
                  , mdControl "secondary"
                  , HP.disabled (String.trim state.libraryUrl == "")
                  , HE.onClick (\_ -> ImportLibraryBookFromUrl)
                  ]
                  [ HH.text "Import book from URL" ]
              ]
          , HH.label
              [ classNames [ "field-stack", "library-file-field" ] ]
              [ HH.span
                  [ classNames [ "field-label" ] ]
                  [ HH.text "Book file" ]
              , HH.input
                  [ HH.attr (HH.AttrName "id") "library-book-file"
                  , HH.attr (HH.AttrName "type") "file"
                  , HH.attr (HH.AttrName "aria-label") "Book file"
                  , HH.attr
                      (HH.AttrName "accept")
                      ".ttl,.json,.txt,application/json,text/turtle,text/plain"
                  , HE.onChange (\_ -> ImportLibraryBookFile)
                  ]
              ]
          , HH.label
              [ classNames [ "field-stack", "library-file-field" ] ]
              [ HH.span
                  [ classNames [ "field-label" ] ]
                  [ HH.text "Book store JSON file" ]
              , HH.input
                  [ HH.attr (HH.AttrName "id") "library-store-file"
                  , HH.attr (HH.AttrName "type") "file"
                  , HH.attr (HH.AttrName "aria-label") "Book store JSON file"
                  , HH.attr (HH.AttrName "accept") ".json,application/json"
                  , HE.onChange (\_ -> ImportLibraryStoreFile)
                  ]
              ]
          ]
      , case state.libraryError of
          Just err ->
            HH.div
              [ classNames [ "sparql-lens-error" ] ]
              [ HH.text (libraryErrorPrefix err <> err) ]
          Nothing -> HH.text ""
      ]

  libraryErrorPrefix err =
    if
      StringCodeUnits.contains (String.Pattern "Save failed") err
        || StringCodeUnits.contains (String.Pattern "Could not read editor draft") err
    then
      "Book save failed: "
    else
      "Book import failed: "

  renderLibraryBooks state =
    HH.div
      [ classNames [ "library-book-list" ] ]
      ( if Array.null state.books then
          [ HH.div
              [ classNames [ "empty-state" ] ]
              [ HH.text "No books stored." ]
          ]
        else
          map (renderLibraryBook state) state.books
      )

  renderLibraryBook state book =
    let
      editName = bookEditName state book
      saveDisabled = String.trim editName == "" || editName == book.name
    in
      HH.element (HH.ElemName "md-elevated-card")
        [ classNames [ "library-book" ]
        , mdSurface "books"
        ]
        [ HH.div
            [ classNames [ "library-book-heading" ] ]
            [ HH.div_
                [ HH.h2_ [ HH.text book.name ]
                , HH.p_ [ HH.text (libraryBookSummary book) ]
                ]
            , HH.label
                [ classNames [ "switch-row", "library-select-row" ] ]
                [ HH.input
                    [ HP.type_ HP.InputCheckbox
                    , HP.checked book.selected
                    , HH.attr (HH.AttrName "aria-label") ("Select " <> book.name)
                    , HE.onChecked (ToggleLibraryBook book.id)
                    ]
                , HH.element (HH.ElemName "md-switch")
                    [ classNames [ "persist-md-switch" ]
                    , HH.attr (HH.AttrName "aria-hidden") "true"
                    , HH.attr (HH.AttrName "tabindex") "-1"
                    ]
                    []
                , HH.span_ [ HH.text "Selected" ]
                ]
            ]
        , HH.div
            [ classNames [ "library-book-meta" ] ]
            [ HH.span_ [ HH.text (if book.seed then "seed" else "local") ]
            , HH.span_ [ HH.text book.source ]
            , HH.span_ [ HH.text (libraryEditorModeLabel (libraryBookEditorMode book) <> " editor") ]
            ]
        , HH.div
            [ classNames [ "library-book-controls" ] ]
            [ HH.label
                [ classNames [ "field-stack", "library-name-field" ] ]
                [ HH.span
                    [ classNames [ "field-label" ] ]
                    [ HH.text "Name" ]
                , HH.input
                    [ HP.type_ HP.InputText
                    , HP.value editName
                    , HH.attr (HH.AttrName "aria-label") ("Rename " <> book.name)
                    , HE.onValueInput (SetLibraryBookName book.id)
                    ]
                ]
            , HH.div
                [ classNames [ "library-row-actions" ] ]
                [ HH.element (HH.ElemName "md-outlined-button")
                    [ classNames [ "secondary-action" ]
                    , HH.attr (HH.AttrName "role") "button"
                    , mdControl "secondary"
                    , HP.disabled saveDisabled
                    , HE.onClick (\_ -> SaveLibraryBookName book.id)
                    ]
                    [ HH.text ("Save name for " <> book.name) ]
                , HH.element (HH.ElemName "md-outlined-button")
                    [ classNames [ "danger-action" ]
                    , HH.attr (HH.AttrName "role") "button"
                    , mdControl "secondary"
                    , HE.onClick (\_ -> DeleteLibraryBook book.id)
                    ]
                    [ HH.text ("Delete " <> book.name) ]
                ]
            ]
        , renderLibraryBookEditor state book
        ]

  renderLibraryBookEditor state book =
    let
      sourceText = libraryBookSourceText book
      editorMode = libraryBookEditorMode book
      saved = state.copiedPath == Just ("library:" <> book.id <> ":saved")
      copied = state.copiedPath == Just ("library:" <> book.id)
    in
      HH.div
        [ classNames [ "library-source-panel" ] ]
        [ HH.div
            [ classNames [ "library-source-heading" ] ]
            [ HH.div_
                [ HH.h3_ [ HH.text "Source" ]
                , HH.p_ [ HH.text "Draft edits stay local until you save." ]
                ]
            , HH.div
                [ classNames [ "library-row-actions", "library-source-actions" ] ]
                [ HH.element (HH.ElemName "md-outlined-button")
                    [ classNames [ "secondary-action" ]
                    , HH.attr (HH.AttrName "role") "button"
                    , mdControl "secondary"
                    , HE.onClick (\_ -> CopyLibraryBookSource book.id)
                    ]
                    [ HH.text
                        ( if copied then
                            "Copied " <> book.name <> " source"
                          else
                            "Copy " <> book.name <> " source"
                        )
                    ]
                , HH.element (HH.ElemName "md-outlined-button")
                    [ classNames [ "secondary-action" ]
                    , HH.attr (HH.AttrName "role") "button"
                    , mdControl "secondary"
                    , HE.onClick (\_ -> SaveLibraryBookSource book.id)
                    ]
                    [ HH.text ("Save " <> book.name <> " source") ]
                , if saved then
                    HH.span
                      [ classNames [ "inline-status" ] ]
                      [ HH.text ("Saved " <> book.name <> " source") ]
                  else
                    HH.text ""
                ]
            ]
        , HH.slot_
            _libraryEditor
            book.id
            libraryEditorComponent
            { value: sourceText
            , mode: editorMode
            }
        ]

  renderSettingsSummary state =
    HH.element (HH.ElemName "md-elevated-card")
      [ classNames [ "settings-summary" ]
      , mdSurface "provider"
      ]
      [ HH.div
          [ classNames [ "settings-summary-copy" ] ]
          [ HH.span
              [ classNames [ "identity-section-title" ] ]
              [ HH.text "Chain data" ]
          , HH.strong_
              [ HH.text
                  (Provider.providerName state.provider <> " / " <> networkName state.network)
              ]
          , HH.div
              [ classNames [ "settings-meta-row" ] ]
              [ HH.span_ [ HH.text "Provider" ]
              , HH.span_ [ HH.text "Network" ]
              , HH.span_ [ HH.text "Key setting" ]
              ]
          ]
      , HH.a
          [ classNames [ "header-link" ]
          , HP.href (state.routeBase <> Routing.routePath RouteSettings)
          , HE.onClick (Navigate RouteSettings)
          ]
          [ HH.text "Settings" ]
      ]

  renderLoadedInspectorHeader state =
    let
      selected = selectedBooks state
      parts = selectedBookParts state
      overlayCount = Array.length (selectedOverlayParts state)
      blueprintCount = Array.length (selectedBlueprintParts state)
      shaclCount = Array.length (selectedShaclParts state)
      txHash = loadedTxHash state
      txIdPath = "loaded-header:tx-id"
      cborPath = "loaded-header:cbor"
      renderContextItem label extraClasses content =
        HH.div
          [ classNames ([ "loaded-context-item" ] <> extraClasses) ]
          ([ HH.span_ [ HH.text label ] ] <> content)
      renderCopyContextValue label path fullValue displayValue =
        HH.div
          [ classNames [ "loaded-context-value" ] ]
          [ HH.code
              [ classNames [ "summary-copy-target" ]
              , HP.title fullValue
              , HE.onClick (\_ -> CopyValue path fullValue)
              ]
              [ HH.text displayValue ]
          , HH.element (HH.ElemName "md-outlined-button")
              [ HE.onClick (\_ -> CopyValue path fullValue)
              , classNames [ "inline-action", "loaded-context-copy" ]
              , HH.attr (HH.AttrName "role") "button"
              , HH.attr (HH.AttrName "aria-label") ("Copy " <> label)
              , mdControl "inline"
              ]
              [ HH.text
                  ( if state.copiedPath == Just path then
                      "Copied"
                    else
                      "Copy"
                  )
              ]
          ]
    in
      HH.section
        [ classNames [ "loaded-inspector-header" ]
        , HH.attr (HH.AttrName "aria-label") "Loaded transaction controls"
        ]
        [ HH.div
            [ classNames [ "loaded-inspector-context" ] ]
            ( [ renderContextItem "Source" [] [ HH.strong_ [ HH.text (modeLabel state.mode) ] ]
              , renderContextItem "Provider" [] [ HH.strong_ [ HH.text (Provider.providerName state.provider) ] ]
              , renderContextItem "Network" [] [ HH.strong_ [ HH.text (networkName state.network) ] ]
              , renderContextItem "Tx id/hash"
                  [ "loaded-context-hash" ]
                  [ renderCopyContextValue "Tx id/hash" txIdPath txHash txHash ]
              ]
                <> (case state.txCbor of
                  Just cbor ->
                    [ renderContextItem "CBOR"
                        [ "loaded-context-cbor" ]
                        [ renderCopyContextValue "CBOR" cborPath cbor (middleTruncate 16 8 cbor) ]
                    ]
                  Nothing ->
                    []
                )
            )
        , HH.div
            [ classNames [ "loaded-book-context" ] ]
            [ HH.span_ [ HH.text (show (Array.length selected) <> " selected") ]
            , HH.span_ [ HH.text (show (Array.length parts) <> " parts") ]
            , HH.span_ [ HH.text (show overlayCount <> " overlays") ]
            , HH.span_ [ HH.text (show blueprintCount <> " blueprints") ]
            , HH.span_ [ HH.text (show shaclCount <> " SHACL") ]
            ]
        , HH.div
            [ classNames [ "loaded-inspector-actions" ] ]
            [ HH.element (HH.ElemName "md-outlined-button")
                [ classNames [ "secondary-action" ]
                , HH.attr (HH.AttrName "role") "button"
                , mdControl "secondary"
                , HE.onClick (\_ -> ChangeInput)
                ]
                [ HH.text "Change input" ]
            , HH.a
                [ classNames [ "header-link" ]
                , HP.href (state.routeBase <> Routing.routePath RouteLibrary)
                , HE.onClick (Navigate RouteLibrary)
                ]
                [ HH.text "Library" ]
            , HH.element (HH.ElemName "md-filled-button")
                [ classNames [ "primary-action" ]
                , HH.attr (HH.AttrName "role") "button"
                , mdControl "primary"
                , HP.disabled state.running
                , HE.onClick (\_ -> ApplySelectedBooks)
                ]
                [ HH.text "Apply selected books" ]
            ]
        ]

  modeLabel mode =
    case mode of
      ByHash -> "Tx hash"
      ByHex  -> "CBOR hex"

  loadedTxHash state =
    case state.identification of
      Just identification | identification.valid ->
        case Array.find (\row -> row.path == "[\"identification\",\"tx_id\"]") identification.primary of
          Just row -> row.value
          Nothing ->
            case Array.find (\row -> row.path == "[\"identification\",\"body_hash\"]") identification.primary of
              Just row -> row.value
              Nothing  -> fallbackInputHash state
      _ -> fallbackInputHash state

  fallbackInputHash state =
    let
      trimmedHash = String.trim state.txHash
    in
      if trimmedHash == "" then "decoded transaction"
      else trimmedHash

  renderBooksPanel state collapsed =
    let
      selected = selectedBooks state
      parts = selectedBookParts state
      overlayCount = Array.length (selectedOverlayParts state)
      blueprintCount = Array.length (selectedBlueprintParts state)
      shaclCount = Array.length (selectedShaclParts state)
      plural n singular pluralForm = show n <> if n == 1 then singular else pluralForm
      pills =
        HH.div
          [ classNames [ "tech-pills" ] ]
          [ HH.span_ [ HH.text (show (Array.length selected) <> " selected") ]
          , HH.span_ [ HH.text (plural (Array.length parts) " part" " parts") ]
          , HH.span_ [ HH.text (plural overlayCount " overlay" " overlays") ]
          , HH.span_ [ HH.text (plural blueprintCount " blueprint" " blueprints") ]
          , HH.span_ [ HH.text (plural shaclCount " SHACL shape" " SHACL shapes") ]
          ]
      libraryLink =
        HH.a
          [ classNames [ "header-link" ]
          , HP.href (state.routeBase <> Routing.routePath RouteLibrary)
          , HE.onClick (Navigate RouteLibrary)
          ]
          [ HH.text "Library" ]
      applyButton =
        HH.element (HH.ElemName "md-filled-button")
          [ classNames [ "primary-action" ]
          , HH.attr (HH.AttrName "role") "button"
          , mdControl "primary"
          , HP.disabled state.running
          , HE.onClick (\_ -> ApplySelectedBooks)
          ]
          [ HH.text "Apply selected books" ]
    in
      if collapsed then
        -- Once a transaction is decoded, the loaded-inspector header already shows the
        -- books summary + Library/Apply controls, so drop the separate Books panel
        -- entirely rather than duplicate that bar; the decoded structure becomes the star.
        HH.text ""
      else
        HH.element (HH.ElemName "md-elevated-card")
          [ classNames [ "panel", "books-panel" ]
          , mdSurface "books"
          ]
          [ HH.div
              [ classNames [ "panel-heading" ] ]
              [ HH.div_
                  [ HH.h2_ [ HH.text "Books" ]
                  , HH.p_ [ HH.text "Selected overlay, blueprint, and SHACL sources." ]
                  ]
              ]
          , pills
          , HH.div
              [ classNames [ "books-actions" ] ]
              [ libraryLink
              , HH.element (HH.ElemName "md-filled-button")
                  [ classNames [ "primary-action" ]
                  , HH.attr (HH.AttrName "role") "button"
                  , mdControl "primary"
                  , HP.disabled state.running
                  , HE.onClick (\_ -> ApplySelectedBooks)
                  ]
                  [ HH.text "Apply selected books" ]
              ]
          , HH.div
              [ classNames [ "books-list" ] ]
              ( if Array.null selected then
                  [ HH.div
                      [ classNames [ "empty-state" ] ]
                      [ HH.text "No selected books. Select books in Library." ]
                  ]
                else
                  map renderSelectedBook selected
              )
          ]

  renderSelectedBook book =
    HH.div
      [ classNames [ "book-summary-row" ] ]
      [ HH.strong_ [ HH.text book.name ]
      , HH.span_
          [ HH.text
              ( libraryBookSummary book
                  <> " - "
                  <> book.source
              )
          ]
      ]

  renderDecodedStructure state =
    HH.element (HH.ElemName "md-elevated-card")
      [ classNames [ "panel", "decoded-structure-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "panel-heading" ] ]
          [ HH.div_
              [ HH.h2_ [ HH.text "Decoded structure" ]
              , HH.p_
                  [ HH.text
                      ( case state.result of
                          Just r ->
                            if r.exitOk then
                              "Stable surface for the structured decoded transaction tree."
                            else
                              "Decode a transaction to populate the structured tree in the next slice."
                          _ ->
                            "Decode a transaction to populate the structured tree in the next slice."
                      )
                  ]
              ]
          ]
      , case state.decodedTreeLens of
          Just lens ->
            renderDecodedTreeLens state lens
          Nothing ->
            HH.div
              [ classNames [ "empty-state", "decoded-structure-placeholder" ] ]
              [ HH.text "Tree renderer pending." ]
      ]

  renderDecodedTreeLens state lens =
    case lens.error of
      Just err ->
        HH.div
          [ classNames [ "sparql-lens-error" ] ]
          [ HH.text ("Decoded-tree query failed: " <> err) ]
      Nothing ->
        if Array.null lens.rows then
          HH.div
            [ classNames [ "empty-state" ] ]
            [ HH.text "No decoded RDF tree rows." ]
        else
          HH.div
            [ classNames [ "decoded-tree-row-list" ] ]
            (renderDecodedTreeRows state "" lens.rows)

  renderDecodedTreeRows state parentId rows =
    groupDecodedEmpties state rows
      (Array.filter (\row -> row.parentId == parentId) rows)

  -- Collapse each run of >=2 consecutive empty (NULL) leaf siblings into one expandable
  -- "N empty fields" chip in place, so populated fields are not buried under a wall of
  -- nulls. CDDL order is preserved (the chip sits at the run's position) and faithfulness
  -- is intact: the chip is a normal tree toggle, so expanding it re-renders every field.
  groupDecodedEmpties state rows children =
    let
      isEmptyLeaf row =
        row.kind == "null" && not (Array.any (\c -> c.parentId == row.id) rows)
      flush run acc =
        case Array.length run of
          0 -> acc
          1 -> acc <> Array.concatMap (renderDecodedTreeRow state rows) run
          _ -> acc <> renderEmptyRun state rows run
      step accRun row =
        if isEmptyLeaf row then
          accRun { run = Array.snoc accRun.run row }
        else
          { acc: flush accRun.run accRun.acc <> renderDecodedTreeRow state rows row, run: [] }
      final = Array.foldl step { acc: [], run: [] } children
    in
      flush final.run final.acc

  renderEmptyRun state rows run =
    let
      groupId = case Array.head run of
        Just r -> "empty::" <> r.id
        Nothing -> "empty::"
      depth = case Array.head run of
        Just r -> r.depth
        Nothing -> 0
      expanded = Array.elem groupId state.decodedEmptyExpanded
      labels = String.joinWith ", " (map _.label run)
      countLabel = show (Array.length run) <> " empty fields"
      rowClasses =
        [ "decoded-tree-row", "decoded-tree-empty-group", "decoded-tree-depth-" <> show depth ]
          <> (if expanded then [ "is-expanded" ] else [])
      chip =
        HH.div
          [ classNames rowClasses ]
          [ HH.div
              [ classNames [ "decoded-tree-main" ] ]
              [ HH.div
                  [ classNames [ "decoded-tree-keyline" ] ]
                  [ HH.element (HH.ElemName "md-outlined-button")
                      [ HE.onClick (\_ -> ToggleDecodedEmpty groupId)
                      , classNames [ "inline-action", "decoded-tree-toggle" ]
                      , HH.attr (HH.AttrName "role") "button"
                      , HH.attr (HH.AttrName "aria-label") countLabel
                      , mdControl "inline"
                      ]
                      [ HH.text countLabel ]
                  , if expanded then HH.text ""
                    else
                      HH.span
                        [ classNames [ "empty-group-labels" ] ]
                        [ HH.text labels ]
                  ]
              ]
          ]
    in
      [ chip ]
        <> (if expanded then Array.concatMap (renderDecodedTreeRow state rows) run else [])

  renderDecodedTreeRow state rows row =
    let
      hasChildren = Array.any (\candidate -> candidate.parentId == row.id) rows
      expanded = row.parentId == "" || Array.elem row.id state.decodedTreeExpanded
      -- Dim empty (NULL) leaf fields so populated fields stand out, while keeping every
      -- CDDL field present and in order (the faithful-decode contract).
      emptyClass = if row.kind == "null" && not hasChildren then [ "decoded-tree-empty-field" ] else []
      rowClasses =
        ( if hasChildren && expanded then
            [ "decoded-tree-row", "is-expanded", "decoded-tree-depth-" <> show row.depth ]
          else
            [ "decoded-tree-row", "decoded-tree-depth-" <> show row.depth ]
        ) <> emptyClass
      summaryText =
        if row.summary == "" then row.value else row.summary
      metaText =
        if row.resolvedLabel /= "" then row.resolvedLabel
        else ""
    in
      [ HH.div
          [ classNames rowClasses
          , HP.id row.id
          ]
          [ HH.div
              [ classNames [ "decoded-tree-main" ] ]
              [ HH.div
                  [ classNames [ "decoded-tree-keyline" ] ]
                  [ if hasChildren then
                      HH.element (HH.ElemName "md-outlined-button")
                        [ HE.onClick (\_ -> ToggleDecodedTree row.id)
                        , classNames [ "inline-action", "decoded-tree-toggle" ]
                        , HH.attr (HH.AttrName "role") "button"
                        , HH.attr
                            (HH.AttrName "aria-label")
                            (row.label <> if row.summary == "" then "" else " " <> row.summary)
                        , mdControl "inline"
                        ]
                        [ HH.text (row.label <> if row.summary == "" then "" else " " <> row.summary) ]
                    else
                      HH.strong_ [ HH.text row.label ]
                  , HH.span
                      [ classNames [ "kind-badge" ] ]
                      [ renderDecodedTreeKind row ]
                  , HH.span
                      [ classNames [ "decoded-tree-actions" ] ]
                      [ renderDecodedTreeAnnotationAction state row ]
                  ]
              , if summaryText == "" then
                  HH.text ""
                else
                  HH.div
                    (decodedTreeSummaryAttrs row summaryText)
                    [ renderDecodedTreeSummary row summaryText ]
              , if metaText == "" then
                  HH.text ""
                else
                  HH.div
                    [ classNames [ "decoded-tree-meta" ] ]
                    [ HH.text metaText ]
              , renderDecodedTreeAnnotation state row
              ]
          ]
      ] <> if expanded && hasChildren then
        [ HH.div
            [ classNames [ "decoded-tree-children" ] ]
            (renderDecodedTreeRows state row.id rows)
        ]
      else []

  renderDecodedTreeKind row =
    if row.resolvedType == "" then
      HH.text row.kind
    else
      renderDecodedTreeIri row.resolvedType

  renderDecodedTreeSummary row summaryText =
    let
      fullSubject = decodedTreeFullSubject row summaryText
    in
      if fullSubject /= "" then
        HH.button
          [ classNames [ "decoded-tree-subject", "summary-copy-target" ]
          , HP.title fullSubject
          , HH.attr (HH.AttrName "aria-label") ("Copy " <> row.label)
          , HE.onClick (\_ -> CopyValue row.id fullSubject)
          ]
          [ HH.text (middleTruncate 24 18 fullSubject) ]
      else
        renderDecodedTreeIri summaryText

  decodedTreeSummaryAttrs row summaryText =
    let
      fullSubject = decodedTreeFullSubject row summaryText
    in
      if fullSubject == "" then
        [ classNames [ "decoded-tree-summary" ] ]
      else
        [ classNames [ "decoded-tree-summary" ]
        , HP.title fullSubject
        ]

  decodedTreeFullSubject row summaryText =
    if isCardanoUrn row.value then row.value
    else if isCardanoUrn summaryText then summaryText
    else ""

  renderDecodedTreeIri value =
    case curieForIri value of
      Just link ->
        HH.a
          [ classNames [ "decoded-tree-iri" ]
          , HP.href link.href
          , HP.target "_blank"
          , HP.rel "noopener noreferrer"
          , HP.title link.href
          ]
          [ HH.text link.label ]
      Nothing ->
        HH.text value

  curieForIri value =
    case Array.find (\prefix -> startsWith prefix.iri value) decodedTreeIriPrefixes of
      Just prefix ->
        Just
          { href: value
          , label:
              prefix.name
                <> StringCodeUnits.drop (StringCodeUnits.length prefix.iri) value
          }
      Nothing ->
        if startsWith "https://" value || startsWith "http://" value then
          Just { href: value, label: middleTruncate 32 24 value }
        else
          Nothing

  decodedTreeIriPrefixes =
    [ { name: "cardano:", iri: "https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#" }
    , { name: "rdf:", iri: "http://www.w3.org/1999/02/22-rdf-syntax-ns#" }
    , { name: "rdfs:", iri: "http://www.w3.org/2000/01/rdf-schema#" }
    , { name: "overlay:", iri: "https://lambdasistemi.github.io/cardano-ledger-inspector/overlay/amaru-treasury#" }
    , { name: "owl:", iri: "http://www.w3.org/2002/07/owl#" }
    , { name: "xsd:", iri: "http://www.w3.org/2001/XMLSchema#" }
    , { name: "sh:", iri: "http://www.w3.org/ns/shacl#" }
    ]

  isCardanoUrn value =
    startsWith "urn:cardano:" value

  startsWith prefix value =
    StringCodeUnits.take (StringCodeUnits.length prefix) value == prefix

  middleTruncate headCount tailCount value =
    let
      valueLength = StringCodeUnits.length value
      limit = headCount + tailCount + 3
    in
      if valueLength <= limit then
        value
      else
        StringCodeUnits.take headCount value
          <> "..."
          <> StringCodeUnits.drop (valueLength - tailCount) value

  renderDecodedTreeAnnotation state row =
    case state.annotationDraft of
      Just draft | draft.rowId == row.id ->
        renderDecodedTreeAnnotationDraft state row draft
      _ ->
        HH.text ""

  renderDecodedTreeAnnotationAction state row =
    case state.annotationDraft of
      Just draft | draft.rowId == row.id ->
        HH.text ""
      _ ->
        if row.resolvedLabel == "" && row.annotationPredicate /= "" && row.annotationValue /= "" then
          HH.element (HH.ElemName "md-icon-button")
            [ classNames [ "inline-action", "decoded-tree-annotate" ]
            , HH.attr (HH.AttrName "role") "button"
            , HH.attr (HH.AttrName "aria-label") "Label this node"
            , mdControl "icon"
            , HE.onClick (\_ -> StartDecodedTreeAnnotation row)
            ]
            [ HH.element (HH.ElemName "md-icon") [] [ HH.text "edit" ] ]
        else
          HH.text ""

  renderDecodedTreeAnnotationDraft state row draft =
    let
      localBooks = selectedLocalBooks state
      hasLocalBooks = not (Array.null localBooks)
      saveDisabled =
        String.trim draft.label == ""
          || row.annotationPredicate == ""
          || row.annotationValue == ""
          || (draft.mode == "new" && String.trim draft.newBookName == "")
          || (draft.mode == "existing" && draft.bookId == "")
    in
      HH.div
        [ classNames [ "decoded-tree-annotation-form" ] ]
        [ HH.label
            [ classNames [ "field-stack" ] ]
            [ HH.span
                [ classNames [ "field-label" ] ]
                [ HH.text "Label" ]
            , HH.input
                [ HP.type_ HP.InputText
                , HP.value draft.label
                , HH.attr (HH.AttrName "aria-label") "Label"
                , HE.onValueInput SetDecodedTreeAnnotationLabel
                ]
            ]
        , HH.label
            [ classNames [ "field-stack" ] ]
            [ HH.span
                [ classNames [ "field-label" ] ]
                [ HH.text "Optional type" ]
            , HH.input
                [ HP.type_ HP.InputText
                , HP.value draft.typeName
                , HH.attr (HH.AttrName "aria-label") "Optional type"
                , HE.onValueInput SetDecodedTreeAnnotationType
                ]
            ]
        , HH.fieldset
            [ classNames [ "annotation-book-mode" ] ]
            [ HH.legend_ [ HH.text "Book" ]
            , HH.label
                [ choiceClass (draft.mode == "new") ]
                [ HH.input
                    [ HP.type_ HP.InputRadio
                    , HP.name ("annotation-book-mode-" <> row.id)
                    , HP.checked (draft.mode == "new")
                    , HE.onChange (\_ -> SetDecodedTreeAnnotationMode "new")
                    ]
                , HH.span
                    [ classNames [ "choice-title" ] ]
                    [ HH.text "Create new local book" ]
                ]
            , HH.label
                [ choiceClass (draft.mode == "existing") ]
                [ HH.input
                    [ HP.type_ HP.InputRadio
                    , HP.name ("annotation-book-mode-" <> row.id)
                    , HP.checked (draft.mode == "existing")
                    , HP.disabled (not hasLocalBooks)
                    , HE.onChange (\_ -> SetDecodedTreeAnnotationMode "existing")
                    ]
                , HH.span
                    [ classNames [ "choice-title" ] ]
                    [ HH.text "Append to existing book" ]
                ]
            ]
        , if draft.mode == "existing" then
            HH.label
              [ classNames [ "field-stack" ] ]
              [ HH.span
                  [ classNames [ "field-label" ] ]
                  [ HH.text "Target book" ]
              , HH.select
                  [ HP.value draft.bookId
                  , HH.attr (HH.AttrName "aria-label") "Target book"
                  , HE.onValueChange SetDecodedTreeAnnotationBookId
                  ]
                  (map renderAnnotationBookOption localBooks)
              ]
          else
            HH.label
              [ classNames [ "field-stack" ] ]
              [ HH.span
                  [ classNames [ "field-label" ] ]
                  [ HH.text "New book name" ]
              , HH.input
                  [ HP.type_ HP.InputText
                  , HP.value draft.newBookName
                  , HH.attr (HH.AttrName "aria-label") "New book name"
                  , HE.onValueInput SetDecodedTreeAnnotationNewBookName
                  ]
              ]
        , case draft.error of
            Just err ->
              HH.div
                [ classNames [ "sparql-lens-error" ] ]
                [ HH.text err ]
            Nothing -> HH.text ""
        , HH.div
            [ classNames [ "annotation-actions" ] ]
            [ HH.element (HH.ElemName "md-filled-button")
                [ classNames [ "primary-action" ]
                , HH.attr (HH.AttrName "role") "button"
                , mdControl "primary"
                , HP.disabled saveDisabled
                , HE.onClick (\_ -> SaveDecodedTreeAnnotation row)
                ]
                [ HH.text "Save label" ]
            , HH.element (HH.ElemName "md-outlined-button")
                [ classNames [ "secondary-action" ]
                , HH.attr (HH.AttrName "role") "button"
                , mdControl "secondary"
                , HE.onClick (\_ -> CancelDecodedTreeAnnotation)
                ]
                [ HH.text "Cancel" ]
            ]
        ]

  renderAnnotationBookOption book =
    HH.option
      [ HP.value book.id ]
      [ HH.text book.name ]

  renderProvider state =
    HH.element (HH.ElemName "md-elevated-card")
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
          , HH.element (HH.ElemName "md-switch")
              [ classNames [ "persist-md-switch" ]
              , HH.attr (HH.AttrName "aria-hidden") "true"
              , HH.attr (HH.AttrName "tabindex") "-1"
              ]
              []
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
    HH.element (HH.ElemName "md-elevated-card")
      [ classNames [ "panel", "input-panel" ]
      , mdSurface "input"
      ]
      [ HH.div
          [ classNames [ "panel-heading" ] ]
          [ HH.h2_ [ HH.text "Paste here" ]
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
      , renderExamplesPicker
      ]

  renderExamplesPicker =
    HH.div
      [ classNames [ "examples-picker" ] ]
      [ HH.div
          [ classNames [ "examples-heading" ] ]
          [ HH.h3_ [ HH.text "Examples" ]
          , HH.p_
              [ HH.text
                  "Load a sample transaction — valid, or deliberately broken — to see the phase-1 validation fire."
              ]
          ]
      , HH.div
          [ classNames [ "example-chips" ] ]
          (map renderExampleChip Examples.examples)
      ]

  renderExampleChip ex =
    HH.element (HH.ElemName "md-outlined-button")
      [ classNames [ "example-chip", "example-" <> ex.severity ]
      , HH.attr (HH.AttrName "role") "button"
      , HP.title ex.description
      , HE.onClick (\_ -> LoadExample ex.cbor)
      ]
      [ HH.span [ classNames [ "example-sev" ] ] [ HH.text (severityIcon ex.severity) ]
      , HH.span [ classNames [ "example-label" ] ] [ HH.text ex.label ]
      ]

  severityIcon sev = case sev of
    "valid" -> "✓"
    "warning" -> "⚠"
    _ -> "✗"

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
        , HH.element (HH.ElemName "md-filled-button")
            [ HP.disabled state.running
            , classNames [ "primary-action" ]
            , HH.attr (HH.AttrName "role") "button"
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
        , HH.element (HH.ElemName "md-filled-button")
            [ HP.disabled state.running
            , classNames [ "primary-action" ]
            , HH.attr (HH.AttrName "role") "button"
            , mdControl "primary"
            , HE.onClick (\_ -> Decode)
            ]
            [ HH.text (if state.running then "Decoding..." else "Decode") ]
        ]

  renderResult state =
    case state.fetchError of
      Just err ->
        HH.element (HH.ElemName "md-elevated-card")
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
          HH.element (HH.ElemName "md-elevated-card")
            [ classNames [ "panel", "result-panel", "empty-result" ]
            , mdSurface "result"
            ]
            [ HH.div
                [ classNames [ "panel-heading" ] ]
                [ HH.h2_ [ HH.text "Decoded structure" ] ]
            , HH.div
                [ classNames [ "empty-state" ] ]
                [ HH.text "No result yet." ]
            ]
        Just r ->
          let
            summary = Json.inspect r.stdout
          in
            HH.element (HH.ElemName "md-elevated-card")
              [ classNames [ "panel", "result-panel" ]
              , mdSurface "result"
              ]
              ( [ HH.div
                    [ classNames [ "panel-heading", "result-heading" ] ]
                    [ HH.div_
                        [ HH.h2_ [ HH.text (if r.exitOk then "Decoded structure" else "Error") ]
                        , if r.exitOk && summary.valid
                            then HH.p_ [ HH.text "Decoded transaction" ]
                            else HH.text ""
                        ]
                    , if r.exitOk
                        then
                          HH.element (HH.ElemName "md-outlined-button")
                            [ HE.onClick (\_ -> Copy)
                            , classNames [ "secondary-action" ]
                            , HH.attr (HH.AttrName "role") "button"
                            , mdControl "secondary"
                            ]
                            [ HH.text (if state.copied then "Copied" else "Copy JSON") ]
                        else HH.text ""
                    ]
                ]
              <> ( if r.exitOk then
                     [ renderResultTabs state
                     , renderSelectedResultTab state r.stdout
                     ]
                   else
                     [ renderRawJson r.stdout ]
                 )
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
            <> renderShaclConformanceMaybe state state.shaclConformance
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

  renderResultSummary state summary =
    HH.div
      [ classNames [ "inspection-summary", "result-summary" ] ]
      ( [ renderResultSummaryTitle state summary
        , HH.div
            [ classNames [ "metric-grid" ] ]
            (map renderMetric summary.metrics)
        ]
          <> renderSummaryIdentity state
          <> renderSummaryWarnings state
      )

  renderResultSummaryTitle state summary =
    case state.identification of
      Just identification | identification.valid ->
        HH.div
          [ classNames [ "result-summary-title" ] ]
          [ HH.h3_ [ HH.text identification.title ]
          , HH.p_ [ HH.text identification.subtitle ]
          ]
      _ -> case state.intent of
        Just intent | intent.valid ->
          HH.div
            [ classNames [ "result-summary-title" ] ]
            [ HH.h3_ [ HH.text intent.title ]
            , HH.p_ [ HH.text intent.subtitle ]
            ]
        _ ->
          HH.div
            [ classNames [ "result-summary-title" ] ]
            [ HH.h3_ [ HH.text summary.title ] ]

  renderSummaryIdentity state =
    case state.identification of
      Just identification ->
        if identification.valid then
          [ HH.div
              [ classNames [ "summary-identity-grid" ] ]
              (map (renderIdentityRow state) identification.primary)
          ]
        else []
      Nothing -> []

  renderSummaryWarnings state =
    [ renderIntentWarnings state.intent
    , renderWitnessPlanWarnings state.witnessPlan
    , renderValidationWarnings state.validation
    ]

  renderIntentWarnings intent =
    case intent of
      Just value | value.valid -> renderWitnessWarnings value.warnings
      _ -> HH.text ""

  renderWitnessPlanWarnings witnessPlan =
    case witnessPlan of
      Just value | value.valid -> renderWitnessWarnings value.warnings
      _ -> HH.text ""

  renderValidationWarnings validation =
    case validation of
      Just value | value.valid -> renderWitnessWarnings value.warnings
      _ -> HH.text ""

  renderResultTabs state =
    HH.div
      [ classNames [ "result-tab-bar" ]
      , HH.attr (HH.AttrName "role") "tablist"
      , HH.attr (HH.AttrName "aria-label") "Inspect result views"
      ]
      (map (renderResultTabButton state.resultTab) resultTabs)

  resultTabs =
    [ StructureTab, WitnessTab, ValidationTab, GraphRdfTab ]

  renderResultTabButton selectedTab tab =
    let
      selected = selectedTab == tab
    in
      HH.button
        [ classNames
            ( if selected then
                [ "result-tab", "is-selected" ]
              else
                [ "result-tab" ]
            )
        , HH.attr (HH.AttrName "role") "tab"
        , HH.attr (HH.AttrName "aria-selected") (if selected then "true" else "false")
        , HE.onClick (\_ -> SelectResultTab tab)
        ]
        [ HH.text (resultTabLabel tab) ]

  renderSelectedResultTab state stdout =
    HH.div
      [ classNames [ "result-tab-panel" ]
      , HH.attr (HH.AttrName "role") "tabpanel"
      , HH.attr (HH.AttrName "aria-label") (resultTabLabel state.resultTab)
      ]
      ( case state.resultTab of
          StructureTab ->
            [ renderDecodedStructure state ]
              <> renderCompactIdentificationMaybe state
          WitnessTab ->
            renderIntentMaybe state
              <> renderWitnessPlanMaybe state
          ValidationTab ->
            renderValidationMaybe state
              <> renderShaclConformanceMaybe state state.shaclConformance
          GraphRdfTab ->
            renderCompactIdentificationMaybe state
              <> renderGraphRdfMaybe state
              <> renderBrowserMaybe state true
              <> [ renderRawJson stdout ]
      )

  renderGraphRdfMaybe state =
    case state.rdf of
      Just rdf ->
        if rdf.valid then
          [ renderRdfGraph rdf, renderOverlayBooks state ]
            <> renderResolvedLabelsLensMaybe state.resolvedLabelsLens
            <> renderTypedFieldsLensMaybe state.typedFieldsLens
            <> renderSparqlLensMaybe state.sparqlLens
        else []
      Nothing -> []

  resultTabLabel tab =
    case tab of
      StructureTab -> "Structure"
      WitnessTab -> "Witness"
      ValidationTab -> "Validation"
      GraphRdfTab -> "Graph / RDF"

  renderCompactIdentificationMaybe state =
    case state.identification of
      Just identification | identification.valid -> [ renderCompactIdentification state identification ]
      _ -> []

  renderCompactIdentification state identification =
    HH.div
      [ classNames [ "identity-panel", "compact-identity-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text "Identity metadata" ]
              , HH.p_ [ HH.text identification.subtitle ]
              ]
          ]
      , HH.div
          [ classNames [ "identity-grid" ] ]
          (map (renderIdentityRow state) identification.primary)
      ]

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
    let
      parts = selectedBookParts state
    in
    HH.div
      [ classNames [ "overlay-book-panel" ]
      , mdSurface "decoded"
      ]
      [ HH.div
          [ classNames [ "identity-heading" ] ]
          [ HH.div_
              [ HH.h3_ [ HH.text "Selected books" ]
              , HH.p_ [ HH.text "Selections are managed in Library and applied to RDF resolution." ]
              ]
          , HH.element (HH.ElemName "md-filled-button")
              [ classNames [ "primary-action" ]
              , HH.attr (HH.AttrName "role") "button"
              , mdControl "primary"
              , HP.disabled state.running
              , HE.onClick (\_ -> ApplySelectedBooks)
              ]
              [ HH.text "Apply selected books" ]
          ]
      , HH.div
          [ classNames [ "overlay-selection-grid" ] ]
          [ HH.div
              [ classNames [ "overlay-part-list" ] ]
              (renderSelectedBookParts parts)
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

  renderSelectedBookParts parts =
    if Array.null parts then
      [ HH.div
          [ classNames [ "witness-empty" ] ]
          [ HH.text "No selected book parts." ]
      ]
    else
      map renderSelectedBookPart parts

  renderSelectedBookPart part =
    HH.div
      [ classNames [ "book-part-row" ] ]
      [ HH.strong_ [ HH.text part.label ]
      , HH.span_ [ HH.text part.kind ]
      ]

  selectedOverlayTurtle state =
    String.joinWith "\n" (map _.turtle (selectedOverlayParts state))

  mergedRdfTurtle transactionGraphTurtle overlayTurtle =
    transactionGraphTurtle <> overlayTurtle

  selectedBooks state =
    BookStore.selectedBooks { kind: BookStore.envelopeKind, books: state.books }

  selectedLocalBooks state =
    Array.filter (\book -> book.selected && not book.seed) state.books

  selectedBookParts state =
    Array.concatMap _.parts (selectedBooks state)

  selectedOverlayParts state =
    Array.filter
      (\part -> part.kind == "overlay")
      (selectedBookParts state)

  selectedBlueprintParts state =
    Array.filter
      (\part -> part.kind == "blueprint")
      (selectedBookParts state)

  selectedShaclParts state =
    Array.filter
      (\part -> part.kind == "shacl")
      (selectedBookParts state)

  selectedShaclTurtle state =
    String.joinWith "\n" (map _.turtle (selectedShaclParts state))

  selectedShaclLabels state =
    map _.label (selectedShaclParts state)

  selectedBlueprintArgs state =
    OverlayBook.blueprintArgs (selectedBlueprintParts state)

  renderShaclConformanceMaybe state conformance =
    case conformance of
      Just value -> [ renderShaclConformance state value ]
      Nothing -> []

  renderShaclConformance state conformance =
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
                  , renderShaclViolations state report
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

  renderShaclViolations state report =
    if Array.null report.violations then
      HH.div
        [ classNames [ "witness-empty" ] ]
        [ HH.text "No phase-1 issues." ]
    else
      HH.div
        [ classNames [ "witness-section" ] ]
        [ HH.div
            [ classNames [ "identity-section-title" ] ]
            [ HH.text "Phase-1 issues" ]
        , HH.div
            [ classNames [ "sparql-lens-row-list" ] ]
            (map (renderShaclViolationRow state) report.violations)
        ]

  renderShaclViolationRow state violation =
    let
      severity = normalizedShaclSeverity violation.severity
    in
    HH.div
      [ classNames [ "sparql-lens-row", "shacl-violation-row", "shacl-" <> severity ] ]
      [ renderShaclViolationCell "Severity" severity
      , renderShaclViolationLocationCell state violation
      , renderShaclViolationCell "Focus node" violation.focusNode
      , renderShaclViolationCell "Path" violation.path
      , renderShaclViolationCell "Source shape" violation.sourceShape
      , renderShaclViolationCell "Message" violation.message
      , renderShaclViolationCell "Constraint" violation.sourceConstraintComponent
      ]

  normalizedShaclSeverity severity =
    if severity == "warning" then "warning"
    else if severity == "info" then "info"
    else "error"

  renderShaclViolationLocationCell state violation =
    HH.div
      [ classNames [ "sparql-lens-cell" ] ]
      [ HH.span
          [ classNames [ "identity-section-title" ] ]
          [ HH.text "Location" ]
      , case shaclFocusRow state violation.focusNode of
          Just row ->
            HH.a
              [ classNames [ "decoded-tree-iri", "shacl-location-link" ]
              , HP.href ("#" <> row.id)
              , HP.title row.entityIri
              , HE.onClick (\_ -> SelectResultTab StructureTab)
              ]
              [ HH.text (shaclFocusRowLabel row) ]
          Nothing ->
            HH.text (if violation.focusNode == "" then "transaction graph" else violation.focusNode)
      ]

  shaclFocusRow state focusNode =
    case state.decodedTreeLens of
      Just lens ->
        if focusNode == "" then
          Nothing
        else
          Array.find
            ( \row ->
                row.entityIri == focusNode
                  || row.value == focusNode
                  || row.raw == focusNode
                  || row.annotationValue == focusNode
            )
            lens.rows
      Nothing -> Nothing

  shaclFocusRowLabel row =
    if row.resolvedLabel /= "" then row.resolvedLabel
    else row.label

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
              HH.element (HH.ElemName "md-outlined-button")
                [ HE.onClick (\_ -> CopyValue row.path row.copyValue)
                , classNames [ "inline-action" ]
                , HH.attr (HH.AttrName "role") "button"
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
          , HH.element (HH.ElemName "md-outlined-button")
              [ HE.onClick (\_ -> CopyValue browser.currentPath browser.currentJson)
              , classNames [ "inline-action" ]
              , HH.attr (HH.AttrName "role") "button"
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
                  , if row.canDive then
                      HH.span
                        [ classNames [ "browser-row-actions" ] ]
                        [
                          HH.element (HH.ElemName "md-outlined-button")
                            [ HE.onClick (\_ -> BrowseJson row.path)
                            , classNames [ "inline-action", "browser-row-action" ]
                            , HH.attr (HH.AttrName "role") "button"
                            , mdControl "inline"
                            ]
                            [ HH.text (if expanded then "Close" else "Open") ]
                        ]
                    else HH.text ""
                  ]
              , HH.div
                  [ classNames [ "browser-summary", "summary-copy-target" ]
                  , HE.onClick (\_ -> CopyValue row.path row.copyValue)
                  , HP.title "Copy value"
                  ]
                  [ HH.text row.summary ]
              ]
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

  defaultDecodedTreeExpanded lens =
    case lens of
      Nothing -> []
      Just decoded ->
        decoded.rows
          # Array.filter (\row -> row.parentId == "" || row.depth <= 2)
          # map _.id

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

  decodedTreeLensFromGraph graphTurtle = do
    lensResult <- liftEffect (RdfShapes.queryDecodedTree graphTurtle)
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
    decodedTreeLens <- decodedTreeLensFromGraph graphTurtle
    shaclConformance <- shaclConformanceFromGraph graphTurtle st
    pure
      { sparqlLens
      , resolvedLabelsLens
      , typedFieldsLens
      , decodedTreeLens
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

  decodedTreeLensForState st =
    case st.rdf of
      Just rdf ->
        if rdf.valid then
          decodedTreeLensFromGraph
            (mergedRdfTurtle rdf.turtle (selectedOverlayTurtle st))
        else
          pure Nothing
      Nothing -> pure Nothing

  handleAction = case _ of
    Initialize -> pure unit
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
    LoadExample hex -> do
      H.modify_ _ { mode = ByHex, txHex = hex, copied = false, copiedPath = Nothing, fetchError = Nothing }
      handleAction Decode
    SetLibraryInput s -> H.modify_ _ { libraryInput = s, libraryError = Nothing }
    SetLibraryUrl s -> H.modify_ _ { libraryUrl = s, libraryError = Nothing }
    AddLibraryBook -> do
      st <- H.get
      importLibraryBookText st.libraryInput
    ImportLibraryBookFile -> do
      fileText <- H.liftAff (attempt (Storage.readFileInputText "library-book-file"))
      case fileText of
        Left err ->
          H.modify_ _ { libraryError = Just ("File import failed: " <> message err) }
        Right input ->
          importLibraryBookText input
    ImportLibraryBookFromUrl -> do
      st <- H.get
      let url = String.trim st.libraryUrl
      if url == "" then
        H.modify_ _ { libraryError = Just "Book URL is empty." }
      else do
        fetched <- H.liftAff (attempt (Storage.fetchText url))
        case fetched of
          Left err ->
            H.modify_ _ { libraryError = Just ("URL import failed: " <> message err) }
          Right input ->
            importLibraryBookText input
    ExportSelectedLibraryBooks -> do
      st <- H.get
      let
        store =
          { kind: BookStore.envelopeKind
          , books:
              BookStore.selectedBooks
                { kind: BookStore.envelopeKind, books: st.books }
          }
      liftEffect
        ( Storage.downloadJson
            "cardano-ledger-inspector-selected-books.json"
            (BookStore.serialize store)
        )
      H.modify_ _ { libraryError = Nothing }
    ExportAllLibraryBooks -> do
      st <- H.get
      let store = { kind: BookStore.envelopeKind, books: st.books }
      liftEffect
        ( Storage.downloadJson
            "cardano-ledger-inspector-books.json"
            (BookStore.serialize store)
        )
      H.modify_ _ { libraryError = Nothing }
    ImportLibraryStoreFile -> do
      fileText <- H.liftAff (attempt (Storage.readFileInputText "library-store-file"))
      case fileText of
        Left err ->
          H.modify_ _ { libraryError = Just ("Store import failed: " <> message err) }
        Right input ->
          case BookStore.parseStore input of
            Left err ->
              H.modify_ _ { libraryError = Just ("Store import failed: " <> err) }
            Right imported -> do
              st <- H.get
              let
                books = mergeImportedBooks st.books imported.books
                edits = bookNameEditsFromBooks books
              liftEffect (saveBooks books)
              H.modify_
                _
                  { books = books
                  , bookNameEdits = edits
                  , libraryError = Nothing
                  }
    ToggleLibraryBook bookId selected -> do
      st <- H.get
      let books = updateBook bookId (_ { selected = selected }) st.books
      liftEffect (saveBooks books)
      H.modify_ _ { books = books }
    SetLibraryBookName bookId name ->
      H.modify_ \st ->
        st
          { bookNameEdits = upsertBookNameEdit bookId name st.bookNameEdits
          , copiedPath = Nothing
          }
    SaveLibraryBookName bookId -> do
      st <- H.get
      let
        nextName = String.trim (bookEditNameById bookId st)
        books =
          if nextName == "" then
            st.books
          else
            updateBook bookId (_ { name = nextName }) st.books
        edits = bookNameEditsFromBooks books
      liftEffect (saveBooks books)
      H.modify_ _ { books = books, bookNameEdits = edits }
    DeleteLibraryBook bookId -> do
      st <- H.get
      case Array.find (\book -> book.id == bookId) st.books of
        Nothing -> pure unit
        Just book -> do
          confirmed <- liftEffect do
            win <- window
            Window.confirm ("Delete " <> book.name <> "?") win
          when confirmed do
            let
              books = Array.filter (\candidate -> candidate.id /= bookId) st.books
              edits = Array.filter (\edit -> edit.id /= bookId) st.bookNameEdits
            liftEffect (saveBooks books)
            H.modify_ _ { books = books, bookNameEdits = edits }
    CopyLibraryBookSource bookId -> do
      st <- H.get
      case Array.find (\book -> book.id == bookId) st.books of
        Nothing -> pure unit
        Just book -> do
          draft <- H.request _libraryEditor bookId GetLibraryEditorValue
          H.liftAff
            ( Clipboard.copy
                ( case draft of
                    Just value -> value
                    Nothing    -> libraryBookSourceText book
                )
            )
          H.modify_ _ { copiedPath = Just ("library:" <> bookId) }
    SaveLibraryBookSource bookId -> do
      st <- H.get
      case Array.find (\book -> book.id == bookId) st.books of
        Nothing -> pure unit
        Just book -> do
          draft <- H.request _libraryEditor bookId GetLibraryEditorValue
          case draft of
            Nothing ->
              H.modify_
                _
                  { libraryError = Just ("Could not read editor draft for " <> book.name <> ".")
                  , copiedPath = Nothing
                  }
            Just value -> do
              parsed <- liftEffect (OverlayBook.parse value)
              case parsed of
                Left err ->
                  H.modify_
                    _
                      { libraryError = Just ("Save failed for " <> book.name <> ": " <> err)
                      , copiedPath = Nothing
                      }
                Right parsedBook -> do
                  let
                    books =
                      updateBook bookId
                        ( _
                            { raw = value
                            , source = parsedBook.source
                            , parts = parsedBook.parts
                            , turtle = parsedBook.turtle
                            }
                        )
                        st.books
                    edits = bookNameEditsFromBooks books
                  liftEffect (saveBooks books)
                  H.modify_
                    _
                      { books = books
                      , bookNameEdits = edits
                      , libraryError = Nothing
                      , copiedPath = Just ("library:" <> bookId <> ":saved")
                      }
    ApplySelectedBooks -> do
      st <- H.get
      case st.txCbor of
        Nothing -> do
          resolvedLabelsLens <- resolvedLabelsLensForState st
          decodedTreeLens <- decodedTreeLensForState st
          shaclConformance <- shaclConformanceForState st
          H.modify_
            _
              { resolvedLabelsLens = resolvedLabelsLens
              , decodedTreeLens = decodedTreeLens
              , shaclConformance = shaclConformance
              }
        Just txCbor -> do
          H.modify_ _ { running = true, fetchError = Nothing }
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
                , decodedTreeLens = lenses.decodedTreeLens
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
                , decodedTreeLens = Nothing
                , shaclConformance = Nothing
                , fetchError =
                    Just
                      ( if rdfResult.stderr == "" then
                          "Haskell ledger operation tx.rdf failed."
                        else
                          rdfResult.stderr
                      )
                }
    StartDecodedTreeAnnotation row -> do
      st <- H.get
      let
        localBooks = selectedLocalBooks st
        firstBookId =
          case Array.head localBooks of
            Just book -> book.id
            Nothing   -> ""
        mode =
          if Array.null localBooks then "new" else "existing"
      H.modify_
        _
          { annotationDraft =
              Just
                { rowId: row.id
                , label: ""
                , typeName: ""
                , mode
                , bookId: firstBookId
                , newBookName: "Inline fixture annotations"
                , error: Nothing
                }
          }
    SetDecodedTreeAnnotationLabel value ->
      updateAnnotationDraft \draft -> draft { label = value, error = Nothing }
    SetDecodedTreeAnnotationType value ->
      updateAnnotationDraft \draft -> draft { typeName = value, error = Nothing }
    SetDecodedTreeAnnotationMode mode ->
      updateAnnotationDraft \draft -> draft { mode = mode, error = Nothing }
    SetDecodedTreeAnnotationBookId bookId ->
      updateAnnotationDraft \draft -> draft { bookId = bookId, error = Nothing }
    SetDecodedTreeAnnotationNewBookName value ->
      updateAnnotationDraft \draft -> draft { newBookName = value, error = Nothing }
    CancelDecodedTreeAnnotation ->
      H.modify_ _ { annotationDraft = Nothing }
    SaveDecodedTreeAnnotation row -> do
      st <- H.get
      case st.annotationDraft of
        Nothing -> pure unit
        Just draft ->
          saveDecodedTreeAnnotation st row draft
    Decode -> do
      st <- H.get
      H.modify_
        _
          { running = true
          , result = Nothing
          , loadFormExpanded = true
          , resultTab = StructureTab
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
          , decodedTreeLens = Nothing
          , shaclConformance = Nothing
          , browserNodes = []
          , expandedPaths = []
          , decodedTreeExpanded = []
          , decodedEmptyExpanded = []
          , annotationDraft = Nothing
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
        Left err -> H.modify_ _ { running = false, loadFormExpanded = true, fetchError = Just err, browserPath = "[]" }
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
                , decodedTreeLens: Nothing
                , shaclConformance: Nothing
                }
          H.modify_
            _
              { running = false
              , result = Just inspectionResult
              , loadFormExpanded = not (isDecodedResult inspectionResult)
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
              , decodedTreeLens = lenses.decodedTreeLens
              , shaclConformance = lenses.shaclConformance
              , browserNodes =
                  if operationResult.exitOk && browser.valid then rootBrowserNodes browser
                  else []
              , expandedPaths = []
              , decodedTreeExpanded = defaultDecodedTreeExpanded lenses.decodedTreeLens
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
    ToggleDecodedTree rowId -> do
      H.modify_
        \st ->
          st
            { decodedTreeExpanded =
                if Array.elem rowId st.decodedTreeExpanded then
                  closePath rowId st.decodedTreeExpanded
                else
                  expandPath rowId st.decodedTreeExpanded
            }
    ToggleDecodedEmpty groupId ->
      H.modify_
        \st ->
          st
            { decodedEmptyExpanded =
                if Array.elem groupId st.decodedEmptyExpanded then
                  Array.delete groupId st.decodedEmptyExpanded
                else
                  Array.cons groupId st.decodedEmptyExpanded
            }
    SelectResultTab tab ->
      H.modify_ _ { resultTab = tab }
    ChangeInput ->
      H.modify_ _ { loadFormExpanded = true, copied = false, copiedPath = Nothing }

  updateAnnotationDraft update =
    H.modify_ \st -> st { annotationDraft = map update st.annotationDraft }

  annotationError messageText =
    updateAnnotationDraft \draft -> draft { error = Just messageText }

  saveDecodedTreeAnnotation st row draft = do
    let
      label = String.trim draft.label
      typeName = String.trim draft.typeName
      targetName = String.trim draft.newBookName
      turtle =
        BookStore.annotationTurtle
          { label
          , typeName
          , entityIri: row.entityIri
          , predicate: row.annotationPredicate
          , value: row.annotationValue
          }
    if label == "" then
      annotationError "Label is required."
    else if row.entityIri == "" || row.annotationPredicate == "" || row.annotationValue == "" || turtle == "" then
      annotationError "This decoded row does not expose a supported annotation identifier."
    else if draft.mode == "existing" then
      case Array.find (\book -> book.id == draft.bookId && book.selected && not book.seed) st.books of
        Nothing ->
          annotationError "Choose a selected local book."
        Just targetBook -> do
          let combined = appendTurtle targetBook.raw turtle
          parsed <- liftEffect (OverlayBook.parse combined)
          case parsed of
            Left err ->
              annotationError ("Generated Turtle did not parse: " <> err)
            Right parsedBook -> do
              let
                books =
                  updateBook
                    targetBook.id
                    ( \book ->
                        book
                          { raw = combined
                          , parts = parsedBook.parts
                          , turtle = parsedBook.turtle
                          }
                    )
                    st.books
              persistAnnotationBooks books
    else if targetName == "" then
      annotationError "New book name is required."
    else do
      parsed <- liftEffect (OverlayBook.parse turtle)
      case parsed of
        Left err ->
          annotationError ("Generated Turtle did not parse: " <> err)
        Right parsedBook -> do
          let
            newBook =
              { id: nextLocalBookId st.books
              , name: targetName
              , source: "annotation"
              , raw: turtle
              , parts: parsedBook.parts
              , turtle: parsedBook.turtle
              , selected: true
              , seed: false
              }
            books = Array.snoc st.books newBook
          persistAnnotationBooks books

  appendTurtle existing fragment =
    if String.trim existing == "" then
      String.trim fragment <> "\n"
    else
      String.trim existing <> "\n\n" <> String.trim fragment <> "\n"

  persistAnnotationBooks books = do
    let edits = bookNameEditsFromBooks books
    liftEffect (saveBooks books)
    st <- H.get
    let stWithBooks = st { books = books, bookNameEdits = edits, annotationDraft = Nothing, libraryError = Nothing }
    resolvedLabelsLens <- resolvedLabelsLensForState stWithBooks
    decodedTreeLens <- decodedTreeLensForState stWithBooks
    shaclConformance <- shaclConformanceForState stWithBooks
    H.modify_
      _
        { books = books
        , bookNameEdits = edits
        , annotationDraft = Nothing
        , libraryError = Nothing
        , resolvedLabelsLens = resolvedLabelsLens
        , decodedTreeLens = decodedTreeLens
        , shaclConformance = shaclConformance
        }

  importLibraryBookText raw = do
    let input = String.trim raw
    if input == "" then
      H.modify_ _ { libraryError = Just "Book input is empty." }
    else do
      parsed <- liftEffect (OverlayBook.parse input)
      case parsed of
        Left err ->
          H.modify_ _ { libraryError = Just err }
        Right book ->
          appendLibraryBook input book

  appendLibraryBook input book = do
    st <- H.get
    let
      newBook =
        { id: nextLocalBookId st.books
        , name: book.title
        , source: book.source
        , raw: input
        , parts: book.parts
        , turtle: book.turtle
        , selected: true
        , seed: false
        }
      books = Array.snoc st.books newBook
      edits = bookNameEditsFromBooks books
    liftEffect (saveBooks books)
    H.modify_
      _
        { books = books
        , bookNameEdits = edits
        , libraryInput = ""
        , libraryUrl = ""
        , libraryError = Nothing
        }

  saveBooks books =
    BookStore.save { kind: BookStore.envelopeKind, books }

  nextLocalBookId books =
    "local:" <> show (Array.foldl max 0 (Array.mapMaybe localBookNumber books) + 1)

  localBookNumber book =
    localIdNumber book.id

  localIdNumber value =
    let
      prefix = "local:"
    in
      if StringCodeUnits.take (StringCodeUnits.length prefix) value == prefix then
        Int.fromString (StringCodeUnits.drop (StringCodeUnits.length prefix) value)
      else
        Nothing

  mergeImportedBooks existing imported =
    let
      merged =
        Array.foldl
          ( \acc book ->
              let
                nextBook =
                  if Array.elem book.id acc.ids then
                    book { id = nextAvailableLocalId acc.ids }
                  else
                    book
              in
                { ids: Array.snoc acc.ids nextBook.id
                , books: Array.snoc acc.books nextBook
                }
          )
          { ids: map _.id existing, books: existing }
          imported
    in
      merged.books

  nextAvailableLocalId ids =
    "local:" <> show (Array.foldl max 0 (Array.mapMaybe localIdNumber ids) + 1)

  updateBook bookId update books =
    map
      (\book -> if book.id == bookId then update book else book)
      books

  bookNameEditsFromBooks books =
    map (\book -> { id: book.id, name: book.name }) books

  upsertBookNameEdit bookId name edits =
    if Array.any (\edit -> edit.id == bookId) edits then
      map
        (\edit -> if edit.id == bookId then edit { name = name } else edit)
        edits
    else
      Array.snoc edits { id: bookId, name }

  bookEditName state book =
    case Array.find (\edit -> edit.id == book.id) state.bookNameEdits of
      Just edit -> edit.name
      Nothing   -> book.name

  bookEditNameById bookId state =
    case Array.find (\edit -> edit.id == bookId) state.bookNameEdits of
      Just edit -> edit.name
      Nothing ->
        case Array.find (\book -> book.id == bookId) state.books of
          Just book -> book.name
          Nothing   -> ""

  libraryBookSummary book =
    let
      partCount = Array.length book.parts
    in
      show partCount <> if partCount == 1 then " part" else " parts"

  libraryBookSourceText book =
    if String.trim book.raw == "" then book.source else book.raw

  libraryBookEditorMode book =
    let
      source = String.trim (libraryBookSourceText book)
      first = StringCodeUnits.take 1 source
    in
      if first == "{" || first == "[" then RdfEditor.Json else RdfEditor.Turtle

  libraryEditorModeLabel = case _ of
    RdfEditor.Json -> "JSON"
    RdfEditor.Turtle -> "Turtle"

_libraryEditor :: Proxy "libraryEditor"
_libraryEditor = Proxy

type LibraryEditorInput =
  { value :: String
  , mode :: RdfEditor.Mode
  }

type LibraryEditorState =
  { value :: String
  , mode :: RdfEditor.Mode
  , handle :: Maybe RdfEditor.Handle
  }

data LibraryEditorAction
  = InitializeLibraryEditor
  | ReceiveLibraryEditorInput LibraryEditorInput
  | FinalizeLibraryEditor

data LibraryEditorQuery a
  = GetLibraryEditorValue (String -> a)

libraryEditorComponent
  :: forall m
   . MonadAff m
  => H.Component LibraryEditorQuery LibraryEditorInput Void m
libraryEditorComponent =
  H.mkComponent
    { initialState: \input ->
        { value: input.value
        , mode: input.mode
        , handle: Nothing
        }
    , render: renderLibraryEditor
    , eval:
        H.mkEval
          H.defaultEval
            { handleAction = handleLibraryEditorAction
            , handleQuery = handleLibraryEditorQuery
            , initialize = Just InitializeLibraryEditor
            , receive = Just <<< ReceiveLibraryEditorInput
            , finalize = Just FinalizeLibraryEditor
            }
    }

renderLibraryEditor
  :: forall m
   . LibraryEditorState
  -> H.ComponentHTML LibraryEditorAction () m
renderLibraryEditor _ =
  HH.div
    [ HP.classes [ HH.ClassName "rdf-editor-host" ]
    , HP.ref (H.RefLabel "rdf-editor-host")
    ]
    []

handleLibraryEditorAction
  :: forall m
   . MonadAff m
  => LibraryEditorAction
  -> H.HalogenM LibraryEditorState LibraryEditorAction () Void m Unit
handleLibraryEditorAction = case _ of
  InitializeLibraryEditor -> do
    st <- H.get
    target <- H.getHTMLElementRef (H.RefLabel "rdf-editor-host")
    case target of
      Nothing -> pure unit
      Just element -> do
        handle <-
          liftEffect
            ( RdfEditor.mount
                (unsafeCoerce element)
                { value: st.value
                , mode: st.mode
                }
            )
        H.modify_ _ { handle = Just handle }
  ReceiveLibraryEditorInput input -> do
    st <- H.get
    case st.handle of
      Nothing ->
        H.modify_ _ { value = input.value, mode = input.mode }
      Just handle -> do
        when (st.value /= input.value) do
          liftEffect (RdfEditor.setValue handle input.value)
        when (not (sameLibraryEditorMode st.mode input.mode)) do
          liftEffect (RdfEditor.setMode handle input.mode)
        H.modify_ _ { value = input.value, mode = input.mode }
  FinalizeLibraryEditor -> do
    st <- H.get
    case st.handle of
      Nothing -> pure unit
      Just handle -> do
        liftEffect (RdfEditor.dispose handle)
        H.modify_ _ { handle = Nothing }

handleLibraryEditorQuery
  :: forall a m
   . MonadAff m
  => LibraryEditorQuery a
  -> H.HalogenM LibraryEditorState LibraryEditorAction () Void m (Maybe a)
handleLibraryEditorQuery = case _ of
  GetLibraryEditorValue reply -> do
    st <- H.get
    value <- case st.handle of
      Just handle -> liftEffect (RdfEditor.getValue handle)
      Nothing     -> pure st.value
    pure (Just (reply value))

sameLibraryEditorMode :: RdfEditor.Mode -> RdfEditor.Mode -> Boolean
sameLibraryEditorMode RdfEditor.Json RdfEditor.Json = true
sameLibraryEditorMode RdfEditor.Turtle RdfEditor.Turtle = true
sameLibraryEditorMode _ _ = false
