module FFI.Json
  ( Breadcrumb
  , Browser
  , BrowserRow
  , Identification
  , IdentificationRow
  , Inspection
  , Metric
  , MintRow
  , OutputRow
  , Validation
  , WitnessPlan
  , WitnessPlanRow
  , WitnessPlanSection
  , inspect
  , operationBrowser
  , operationIdentification
  , operationInspection
  , operationValidation
  , operationWitnessPlan
  , operationArgsWithPath
  , pretty
  ) where

foreign import prettyImpl :: String -> String
foreign import inspectImpl :: String -> Inspection
foreign import operationInspectionImpl :: String -> String
foreign import operationBrowserImpl :: String -> Browser
foreign import operationIdentificationImpl :: String -> Identification
foreign import operationValidationImpl :: String -> Validation
foreign import operationWitnessPlanImpl :: String -> WitnessPlan
foreign import operationArgsWithPathImpl :: String -> String -> String

type Metric =
  { label :: String
  , value :: String
  }

type OutputRow =
  { index :: String
  , address :: String
  , coin :: String
  , assets :: String
  , datum :: String
  }

type MintRow =
  { policy :: String
  , assets :: String
  }

type Inspection =
  { valid :: Boolean
  , title :: String
  , subtitle :: String
  , metrics :: Array Metric
  , outputs :: Array OutputRow
  , mint :: Array MintRow
  , inputs :: Array String
  , referenceInputs :: Array String
  , outputNote :: String
  , mintNote :: String
  , inputNote :: String
  }

type Breadcrumb =
  { label :: String
  , path :: String
  }

type BrowserRow =
  { label :: String
  , path :: String
  , kind :: String
  , summary :: String
  , copyValue :: String
  , canDive :: Boolean
  }

type Browser =
  { valid :: Boolean
  , title :: String
  , subtitle :: String
  , currentPath :: String
  , currentJson :: String
  , breadcrumbs :: Array Breadcrumb
  , rows :: Array BrowserRow
  }

type IdentificationRow =
  { label :: String
  , value :: String
  , copyValue :: String
  , path :: String
  }

type Identification =
  { valid :: Boolean
  , title :: String
  , subtitle :: String
  , primary :: Array IdentificationRow
  , witnesses :: Array IdentificationRow
  }

type WitnessPlanRow =
  { label :: String
  , value :: String
  , copyValue :: String
  , path :: String
  , detail :: String
  }

type WitnessPlanSection =
  { title :: String
  , empty :: String
  , rows :: Array WitnessPlanRow
  }

type WitnessPlan =
  { valid :: Boolean
  , title :: String
  , subtitle :: String
  , metrics :: Array Metric
  , warnings :: Array String
  , sections :: Array WitnessPlanSection
  }

type Validation =
  { valid :: Boolean
  , title :: String
  , subtitle :: String
  , metrics :: Array Metric
  , warnings :: Array String
  , sections :: Array WitnessPlanSection
  }

pretty :: String -> String
pretty = prettyImpl

inspect :: String -> Inspection
inspect = inspectImpl

operationInspection :: String -> String
operationInspection = operationInspectionImpl

operationBrowser :: String -> Browser
operationBrowser = operationBrowserImpl

operationIdentification :: String -> Identification
operationIdentification = operationIdentificationImpl

operationValidation :: String -> Validation
operationValidation = operationValidationImpl

operationWitnessPlan :: String -> WitnessPlan
operationWitnessPlan = operationWitnessPlanImpl

operationArgsWithPath :: String -> String -> String
operationArgsWithPath = operationArgsWithPathImpl
