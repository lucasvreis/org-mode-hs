{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Org.Types
  ( -- * Document
    OrgDocument (..)
  , Properties

    -- ** Helpers
  , lookupProperty

    -- * Sections
  , OrgSection (..)
  , TodoKeyword (..)
  , TodoState (..)
  , Tag
  , Priority (..)
  , PlanningInfo (..)

    -- ** Helpers
  , lookupSectionProperty

    -- * OrgContent
  , OrgContent
  , documentContent
  , mapContentM
  , mapContent
  , sectionContent
  , mapSectionContentM
  , mapSectionContent

    -- * Elements
  , OrgElement (..)
  , OrgElementData (..)

    -- ** Greater blocks
  , GreaterBlockType (..)

    -- ** Source blocks
  , SrcLine (..)
  , srcLineContent
  , srcLinesToText
  , srcLineMap

    -- ** Lists
  , ListType (..)
  , OrderedStyle (..)
  , orderedStyle
  , ListItem (..)
  , Bullet (..)
  , Checkbox (..)
  , listItemType

    -- ** Keywords
  , Keywords
  , KeywordValue (..)
  , lookupValueKeyword
  , lookupParsedKeyword
  , lookupBackendKeyword
  , keywordsFromList

    -- ** Tables
  , TableRow (..)
  , TableCell
  , ColumnAlignment (..)

    -- * Objects
  , OrgObject (..)

    -- ** Links
  , LinkTarget (..)
  , Protocol
  , Id
  , linkTargetToText

    -- ** LaTeX fragments
  , FragmentType (..)

    -- ** Citations
  , Citation (..)
  , CiteReference (..)

    -- ** Footnote references
  , FootnoteRefData (..)

    -- ** Timestamps
  , TimestampData (..)
  , DateTime
  , TimestampMark
  , Date
  , Time

    -- * Quotes
  , QuoteType (..)

    -- * Babel
  , BabelCall (..)
  ) where

import Data.Aeson
import Data.Aeson.Encoding (text)
import Data.Char (isDigit, toLower)
import Data.Data (Data)
import Data.Map qualified as M
import Data.Text qualified as T

-- * Document, Sections and Headings

data OrgDocument = OrgDocument
  { documentProperties :: Properties
  , documentChildren :: [OrgElement]
  , documentSections :: [OrgSection]
  }
  deriving (Eq, Ord, Read, Show, Generic)
  deriving anyclass (NFData)

lookupProperty :: Text -> OrgDocument -> Maybe Text
lookupProperty k = M.lookup k . documentProperties

data OrgSection = OrgSection
  { sectionLevel :: Int
  , sectionProperties :: Properties
  , sectionTodo :: Maybe TodoKeyword
  , sectionIsComment :: Bool
  , sectionPriority :: Maybe Priority
  , sectionTitle :: [OrgObject]
  , sectionRawTitle :: Text
  , sectionAnchor :: Id
  -- ^ Section custom ID (Warning: this field is not populated by the parser! in
  -- the near future, fields like this one and the 'Id' type will be removed in
  -- favor of AST extensibility). See also the documentation for 'LinkTarget'
  , sectionTags :: [Tag]
  , sectionPlanning :: PlanningInfo
  , sectionChildren :: [OrgElement]
  , sectionSubsections :: [OrgSection]
  }
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

lookupSectionProperty :: Text -> OrgSection -> Maybe Text
lookupSectionProperty k = M.lookup k . sectionProperties

type OrgContent = ([OrgElement], [OrgSection])

documentContent :: OrgDocument -> OrgContent
documentContent doc = (documentChildren doc, documentSections doc)

mapContentM :: Monad m => (OrgContent -> m OrgContent) -> OrgDocument -> m OrgDocument
mapContentM f d = do
  (c', s') <- f (documentContent d)
  pure $ d {documentChildren = c', documentSections = s'}

mapContent :: (OrgContent -> OrgContent) -> OrgDocument -> OrgDocument
mapContent f = runIdentity . mapContentM (Identity . f)

sectionContent :: OrgSection -> OrgContent
sectionContent sec = (sectionChildren sec, sectionSubsections sec)

mapSectionContentM :: Monad m => (OrgContent -> m OrgContent) -> OrgSection -> m OrgSection
mapSectionContentM f d = do
  (c', s') <- f (sectionContent d)
  pure $ d {sectionChildren = c', sectionSubsections = s'}

mapSectionContent :: (OrgContent -> OrgContent) -> OrgSection -> OrgSection
mapSectionContent f = runIdentity . mapSectionContentM (Identity . f)

type Tag = Text

-- | The states in which a todo item can be
data TodoState = Todo | Done
  deriving (Eq, Ord, Show, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

instance ToJSON TodoState where
  toJSON Todo = "todo"
  toJSON Done = "done"
  toEncoding Todo = text "todo"
  toEncoding Done = text "done"

instance FromJSON TodoState where
  parseJSON =
    genericParseJSON
      defaultOptions
        { constructorTagModifier = map toLower
        }

-- | A to-do keyword like @TODO@ or @DONE@.
data TodoKeyword = TodoKeyword
  { todoState :: TodoState
  , todoName :: Text
  }
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

instance ToJSON TodoKeyword where
  toJSON (TodoKeyword s n) = object ["state" .= s, "name" .= n]
  toEncoding (TodoKeyword s n) = pairs ("state" .= s <> "name" .= n)

instance FromJSON TodoKeyword where
  parseJSON = withObject "Todo Keyword" $ \v ->
    TodoKeyword <$> v .: "state" <*> v .: "name"

data Priority
  = LetterPriority Char
  | NumericPriority Int
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

type Date = (Int, Int, Int, Maybe Text)

type Time = (Int, Int)

type TimestampMark = (Text, Int, Char)

type DateTime = (Date, Maybe Time, Maybe TimestampMark, Maybe TimestampMark)

-- | An Org timestamp, including repetition marks.
data TimestampData
  = TimestampData Bool DateTime
  | TimestampRange Bool DateTime DateTime
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

-- | Planning information for a subtree/headline.
data PlanningInfo = PlanningInfo
  { planningClosed :: Maybe TimestampData
  , planningDeadline :: Maybe TimestampData
  , planningScheduled :: Maybe TimestampData
  }
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

type Properties = Map Text Text

-- * Elements

-- | Org element. Like a Pandoc Block.
data OrgElement = OrgElement {affiliatedKeywords :: Keywords, elementData :: OrgElementData}
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

data OrgElementData
  = -- | Clock
    Clock
      TimestampData
      -- ^ Clock timestamp
      (Maybe Time)
      -- ^ Duration
  | -- | Greater block
    GreaterBlock
      { blkType :: GreaterBlockType
      -- ^ Greater block type
      , blkElements :: [OrgElement]
      -- ^ Greater block elements
      }
  | -- | Drawer
    Drawer
      { drawerName :: Text
      -- ^ Drawer name
      , drawerElements :: [OrgElement]
      -- ^ Drawer elements
      }
  | -- | Plain list
    PlainList
      { listType :: ListType
      -- ^ List types
      , listItems :: [ListItem]
      -- ^ List items
      }
  | -- | Export block
    ExportBlock
      Text
      -- ^ Format
      Text
      -- ^ Contents
  | -- | Example block
    ExampleBlock
      (Map Text Text)
      -- ^ Switches
      [SrcLine]
      -- ^ Contents
  | -- | Source blocks
    SrcBlock
      { srcBlkLang :: Text
      -- ^ Language
      , srcBlkSwitches :: Map Text Text
      -- ^ Switches
      , srcBlkArguments :: [(Text, Text)]
      -- ^ Header arguments
      , srcBlkLines :: [SrcLine]
      -- ^ Contents
      }
  | VerseBlock [[OrgObject]]
  | HorizontalRule
  | Keyword
      { keywordKey :: Text
      , keywordValue :: KeywordValue
      }
  | LaTeXEnvironment
      Text
      -- ^ Environment name
      Text
      -- ^ Environment contents
  | Paragraph [OrgObject]
  | Table [TableRow]
  | FootnoteDef
      Text
      -- ^ Footnote name
      [OrgElement]
      -- ^ Footnote content
  | Comment
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

data QuoteType = SingleQuote | DoubleQuote
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

data SrcLine
  = SrcLine Text
  | RefLine
      Id
      -- ^ Reference id (its anchor)
      Text
      -- ^ Reference name (how it appears)
      Text
      -- ^ Line contents
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

srcLineContent :: SrcLine -> Text
srcLineContent (SrcLine c) = c
srcLineContent (RefLine _ _ c) = c

srcLinesToText :: [SrcLine] -> Text
srcLinesToText = T.unlines . map srcLineContent

srcLineMap :: (Text -> Text) -> SrcLine -> SrcLine
srcLineMap f (SrcLine c) = SrcLine (f c)
srcLineMap f (RefLine i t c) = RefLine i t (f c)

-- Keywords

data KeywordValue
  = ValueKeyword Text
  | ParsedKeyword [OrgObject]
  | BackendKeyword [(Text, Text)]
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

instance Semigroup KeywordValue where
  (ValueKeyword t1) <> (ValueKeyword t2) = ValueKeyword (t1 <> "\n" <> t2)
  (ParsedKeyword t1) <> (ParsedKeyword t2) = ParsedKeyword (t1 <> t2)
  (BackendKeyword b1) <> (BackendKeyword b2) = BackendKeyword (b1 <> b2)
  _ <> x = x

type Keywords = Map Text KeywordValue

lookupValueKeyword :: Text -> Keywords -> Text
lookupValueKeyword key kws = fromMaybe mempty do
  ValueKeyword x <- M.lookup key kws
  return x

lookupParsedKeyword :: Text -> Keywords -> [OrgObject]
lookupParsedKeyword key kws = fromMaybe mempty do
  ParsedKeyword x <- M.lookup key kws
  return x

lookupBackendKeyword :: Text -> Keywords -> [(Text, Text)]
lookupBackendKeyword key kws = fromMaybe mempty do
  BackendKeyword x <- M.lookup key kws
  return x

keywordsFromList :: [(Text, KeywordValue)] -> Keywords
keywordsFromList = M.fromListWith (flip (<>))

-- Greater Blocks

data GreaterBlockType = Center | Quote | Special Text
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

-- Lists

data ListType = Ordered OrderedStyle | Descriptive | Unordered Char
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

data OrderedStyle = OrderedNum | OrderedAlpha
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

orderedStyle :: Text -> OrderedStyle
orderedStyle (T.any isDigit -> True) = OrderedNum
orderedStyle _ = OrderedAlpha

{- | One item of a list. Parameters are bullet, counter cookie, checkbox and
tag.
-}
data ListItem = ListItem Bullet (Maybe Int) (Maybe Checkbox) [OrgObject] [OrgElement]
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

data Bullet = Bullet Char | Counter Text Char
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

data Checkbox = BoolBox Bool | PartialBox
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

listItemType :: ListItem -> ListType
listItemType (ListItem (Counter t _) _ _ _ _) = Ordered (orderedStyle t)
listItemType (ListItem (Bullet _) _ _ (_ : _) _) = Descriptive
listItemType (ListItem (Bullet c) _ _ _ _) = Unordered c

-- Babel call

data BabelCall = BabelCall
  { babelCallName :: Text
  , babelCallHeader1 :: Text
  , babelCallHeader2 :: Text
  , babelCallArguments :: Text
  }
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

-- Tables

data TableRow
  = StandardRow [TableCell]
  | ColumnPropsRow [Maybe ColumnAlignment]
  | RuleRow
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

type TableCell = [OrgObject]

data ColumnAlignment = AlignLeft | AlignCenter | AlignRight
  deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
  deriving anyclass (NFData)

-- * Objects (inline elements)

-- | Objects (inline elements).
data OrgObject
  = Plain Text
  | LineBreak
  | Italic [OrgObject]
  | Underline [OrgObject]
  | Bold [OrgObject]
  | Strikethrough [OrgObject]
  | Superscript [OrgObject]
  | Subscript [OrgObject]
  | Quoted QuoteType [OrgObject]
  | Code Text
  | Verbatim Text
  | Timestamp TimestampData
  | -- | Entity (e.g. @\\alpha{}@)
    Entity
      Text
      -- ^ Name (e.g. @alpha@)
  | LaTeXFragment FragmentType Text
  | -- | Inline export snippet (e.g. @\@\@html:\<br/\>\@\@@)
    ExportSnippet
      Text
      -- ^ Back-end (e.g. @html@)
      Text
      -- ^ Value (e.g. @\<br/\>@)
  | -- | Footnote reference.
    FootnoteRef FootnoteRefData
  | Cite Citation
  | InlBabelCall BabelCall
  | -- | Inline source (e.g. @src_html[:foo bar]{\<br/\>}@)
    Src
      Text
      -- ^ Language (e.g. @html@)
      Text
      -- ^ Parameters (e.g. @:foo bar@)
      Text
      -- ^ Value (e.g. @\<br/\>@)
  | Link LinkTarget [OrgObject]
  | -- | Inline target (e.g. @\<\<\<foo\>\>\>@)
    Target
      Id
      -- ^ Anchor (Warning: this field is not populated by the parser! --- in
      -- the near future, fields like this one and the 'Id' type will be removed
      -- in favor of AST extensibility). See also the documentation for
      -- 'LinkTarget'
      Text
      -- ^ Name
  | -- | Org inline macro (e.g. @{{{poem(red,blue)}}}@)
    Macro
      Text
      -- ^ Macro name (e.g. @"poem"@)
      [Text]
      -- ^ Arguments (e.g. @["red", "blue"]@)
  | -- | Statistic cookies.
    StatisticCookie
      (Either (Int, Int) Int)
      -- ^ Either @[num1/num2]@ or @[percent%]@.
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

-- | Data for a footnote reference.
data FootnoteRefData
  = -- | Label-only footnote reference (e.g. @[fn:foo]@)
    FootnoteRefLabel
      Text
      -- ^ Label (e.g. @foo@)
  | -- | Inline footnote definition (e.g. @[fn:foo::bar]@)
    FootnoteRefDef
      (Maybe Text)
      -- ^ Label (if present, e.g. @foo@)
      [OrgObject]
      -- ^ Content (e.g. @bar@)
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

type Protocol = Text

type Id = Text

{- | Link target. Note that the parser does not resolve internal links. Instead,
they should be resolved using the functions in [@org-exporters@
package](https://github.com/lucasvreis/org-mode-hs). In the near future, the
'InternalLink' constructor and 'Id' type will be removed in favor of AST
extensibility. See also the documentation for 'Target'.
-}
data LinkTarget
  = URILink Protocol Text
  | InternalLink Id
  | UnresolvedLink Text
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

linkTargetToText :: LinkTarget -> Text
linkTargetToText = \case
  URILink prot l -> prot <> ":" <> l
  InternalLink l -> l
  UnresolvedLink l -> l

data FragmentType
  = RawFragment
  | InlMathFragment
  | DispMathFragment
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

data Citation = Citation
  { citationStyle :: Text
  , citationVariant :: Text
  , citationPrefix :: [OrgObject]
  , citationSuffix :: [OrgObject]
  , citationReferences :: [CiteReference]
  }
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)

data CiteReference = CiteReference
  { refId :: Text
  , refPrefix :: [OrgObject]
  , refSuffix :: [OrgObject]
  }
  deriving (Show, Eq, Ord, Read, Typeable, Data, Generic)
  deriving anyclass (NFData)
