module Tests.Elements where

import NeatInterpolation
import Org.Builder qualified as B
import Org.Parser.Elements
import Org.Types
import Tests.Helpers

testElements :: TestTree
testElements =
  testGroup
    "Elements"
    [ "Clock" ~: clock $
        [ "CLOCK: [2012-11-18 Sun 19:26]--[2012-11-18 Sun 19:33] =>  0:07\n"
            =?> let dt1 = ((2012, 11, 18, Just "Sun"), Just (19, 26), Nothing, Nothing)
                    dt2 = ((2012, 11, 18, Just "Sun"), Just (19, 33), Nothing, Nothing)
                 in B.clock (TimestampRange False dt1 dt2) (Just (0, 7))
        ]
    , "Clocks in context" ~: elements $
        [ [text|
            foo
            CLOCK: [2012-11-18 Sun 19:26]--[2012-11-18 Sun 19:33] =>  0:07
            bar
          |]
            =?> let dt1 = ((2012, 11, 18, Just "Sun"), Just (19, 26), Nothing, Nothing)
                    dt2 = ((2012, 11, 18, Just "Sun"), Just (19, 33), Nothing, Nothing)
                 in "foo"
                      <> B.element (B.clock (TimestampRange False dt1 dt2) (Just (0, 7)))
                      <> "bar"
        ]
    , "Comment line" ~: commentLine $
        [ "# this is a comment" =?> Comment
        , "#this line is not a comment" =!> ()
        ]
    , "Paragraph" ~: elements $
        [ --
          [text|
            foobar
            baz
          |]
            =?> B.element (B.para ("foobar" <> "\n" <> "baz"))
        , [text|
            with /wrapped
            markup/ and markup *at end*
            =at start= but not~here~ and
            not _here_right.
          |]
            =?> B.element
              ( B.para
                  ( "with "
                      <> B.italic "wrapped\nmarkup"
                      <> " and markup "
                      <> B.bold "at end"
                      <> "\n"
                      <> B.verbatim "at start"
                      <> " but not~here~ and\nnot _here"
                      <> B.subscript (B.plain "right")
                      <> B.plain "."
                  )
              )
        ]
    , "Affiliated Keywords in Context" ~: elements $
        [ --
          [text|
            #+attr_html: :width 40px :foo bar:joined space :liz buuz
            Hi
          |]
            =?> let kw =
                      BackendKeyword
                        [ ("width", "40px")
                        , ("foo", "bar:joined space")
                        , ("liz", "buuz")
                        ]
                 in B.element' [("attr_html", kw)] (B.para "Hi")
        , [text|
            Some para
            #+caption: hi /guys/

            Hi
          |]
            =?> foldMap
              B.element
              [ B.para "Some para"
              , B.keyword "caption" (B.parsedKeyword $ "hi " <> B.italic "guys")
              , B.para "Hi"
              ]
        , [text|
            #+attr_html: :style color: red
              - foo
          |]
            =?> let kw = BackendKeyword [("style", "color: red")]
                 in B.element'
                      [("attr_html", kw)]
                      ( B.list
                          (Unordered '-')
                          [B.listItemUnord '-' $ B.element $ B.para "foo"]
                      )
        , [text|
            Some para
            #+caption: hi /guys/
            Hi
          |]
            =?> let kw = B.parsedKeyword ("hi " <> B.italic "guys")
                 in B.element (B.para "Some para")
                      <> B.element' [("caption", kw)] (B.para "Hi")
        , [text|
            #+attr_org: :foo bar
            #+begin_center
            Some para
            #+caption: hi /guys/
            #+end_center
            I don't have a caption
          |]
            =?> let kw1 = BackendKeyword [("foo", "bar")]
                    kw2 = B.parsedKeyword ("hi " <> B.italic "guys")
                 in B.element'
                      [("attr_org", kw1)]
                      ( B.greaterBlock
                          Center
                          ( foldMap B.element [B.para "Some para", B.keyword "caption" kw2]
                          )
                      )
                      <> B.element (B.para "I don't have a caption")
        ]
    , "Ordered Lists" ~: plainList $
        [ --
          unlines
            [ "1. our"
            , "2. moment's"
            , "3. else's"
            ]
            =?> B.orderedList OrderedNum '.' ["our", "moment's", "else's"]
        ]
    , "Descriptive Lists" ~: plainList $
        [ "- foo ::   bar"
            =?> B.descriptiveList [("foo", "bar")]
        , "- foo bar  :: baz"
            =?> B.descriptiveList [("foo bar", "baz")]
        , "-   :: ::" =?> B.descriptiveList [("::", mempty)]
        , "-   :: foo ::" =?> B.descriptiveList [(":: foo", mempty)]
        , "-   :: :: bar" =?> B.descriptiveList [("::", "bar")]
        , "-  ::  :::" =?> B.list (Unordered '-') [B.listItemUnord '-' "::  :::"]
        , "- /foo/ :: bar"
            =?> B.descriptiveList [(B.italic "foo", "bar")]
        , "- [[foo][bar]] :: bar"
            =?> B.descriptiveList [(B.link (UnresolvedLink "foo") "bar", "bar")]
        , "- [[foo:prot.co][bar baz]] :: bla :: ble"
            =?> B.descriptiveList [(B.link (URILink "foo" "prot.co") "bar baz", "bla :: ble")]
        ]
    , "Lists in context" ~: elements $
        [ --
          unlines
            [ "- foo bar"
            , ""
            , "  #+caption: foo"
            , "bla"
            ]
            =?> B.element
              ( B.list
                  (Unordered '-')
                  [ B.listItemUnord '-' $
                      "foo bar" <> B.element (B.keyword "caption" $ B.parsedKeyword "foo")
                  ]
              )
            <> "bla"
        , unlines
            [ "- foo bar"
            , "#+caption: foo"
            , "  bla"
            ]
            =?> B.element
              ( B.list
                  (Unordered '-')
                  [ B.listItemUnord '-' "foo bar"
                  ]
              )
            <> B.element' [("caption", B.parsedKeyword "foo")] (B.para "bla")
        , unlines
            [ "- "
            , " * "
            , " - foo"
            , " -"
            , " + "
            , "+"
            ]
            =?> B.element
              ( B.list
                  (Unordered '-')
                  [ B.listItemUnord '-' $
                      B.element $
                        B.list
                          (Unordered '*')
                          [ B.listItemUnord '*' mempty
                          , B.listItemUnord '-' "foo"
                          , B.listItemUnord '-' mempty
                          , B.listItemUnord '+' mempty
                          ]
                  , B.listItemUnord '+' mempty
                  ]
              )
        , unlines
            [ "- "
            , ""
            , "- foo"
            , "  "
            , "  "
            , " * bar"
            , " *"
            , ""
            , ""
            , " - doo"
            ]
            =?> B.element
              ( B.list
                  (Unordered '-')
                  [ B.listItemUnord '-' mempty
                  , B.listItemUnord '-' "foo"
                  ]
              )
            <> B.element
              ( B.list
                  (Unordered '*')
                  [ B.listItemUnord '*' "bar"
                  , B.listItemUnord '*' mempty
                  ]
              )
            <> B.element
              ( B.list
                  (Unordered '-')
                  [ B.listItemUnord '-' "doo"
                  ]
              )
        , unlines
            [ " "
            , " 1. our"
            , " 2. moment's"
            , " 3. else's"
            ]
            =?> B.element
              ( B.orderedList
                  OrderedNum
                  '.'
                  (map (B.element . B.para) ["our", "moment's", "else's"])
              )
        ]
    , "Greater Blocks" ~: greaterBlock $
        [ --
          unlines
            [ "#+begin_fun"
            , "    "
            , "#+end_fun"
            ]
            =?> B.greaterBlock (Special "fun") mempty
        ]
    , "Fixed width" ~: fixedWidth $
        [ --
          [text|
                :   fooblabla boo
             :  foooo
                  :       booo
            |]
            =?> B.example
              mempty
              [ SrcLine " fooblabla boo"
              , SrcLine "foooo"
              , SrcLine "     booo"
              ]
        ]
    , "Horizontal Rules" ~: horizontalRule $
        [ "----------------   "
            =?> B.horizontalRule
        , "--   "
            =!> ()
        ]
    , "Tables" ~: table $
        [ --
          [text|
             | foo | bar | baz |
                |foo bar | baz
            |----
            |<r>  | | <l>|<c>
            | <r> | foo /bar/ | *ba* | baz
            | foo || bar | |
          |]
            =?> B.table
              [ B.standardRow ["foo", "bar", "baz"]
              , B.standardRow ["foo bar", "baz"]
              , RuleRow
              , ColumnPropsRow [Just AlignRight, Nothing, Just AlignLeft, Just AlignCenter]
              , B.standardRow ["<r>", "foo " <> B.italic "bar", B.bold "ba", "baz"]
              , B.standardRow ["foo", mempty, "bar", mempty]
              ]
        ]
    , "Tricky whitespace" ~: elements $
        [ "\n    " =?> mempty
        , "" =?> mempty
        , "\n" =?> mempty
        , "\n\n a" =?> B.element (B.para "a")
        ]
    ]
