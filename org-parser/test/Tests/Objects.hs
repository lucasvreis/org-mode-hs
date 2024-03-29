module Tests.Objects where

import Org.Builder qualified as B
import Org.Parser.Objects
import Org.Types
import Tests.Helpers

testObjects :: TestTree
testObjects =
  testGroup
    "Objects"
    [ "Timestamp" ~: timestamp $
        [ "<1997-11-03 Mon 19:15>"
            =?> B.timestamp
              (TimestampData True ((1997, 11, 3, Just "Mon"), Just (19, 15), Nothing, Nothing))
        , "[2020-03-04 20:20]"
            =?> B.timestamp
              (TimestampData False ((2020, 03, 04, Nothing), Just (20, 20), Nothing, Nothing))
        , "[2020-03-04 0:20]"
            =?> B.timestamp
              (TimestampData False ((2020, 03, 04, Nothing), Just (0, 20), Nothing, Nothing))
        ]
    , "Citations" ~: citation $
        [ "[cite:/foo/;/bar/@bef=bof=;/baz/]"
            =?> let ref =
                      CiteReference
                        { refId = "bef"
                        , refPrefix = [Italic [Plain "bar"]]
                        , refSuffix = [Verbatim "bof"]
                        }
                 in B.citation
                      Citation
                        { citationStyle = ""
                        , citationVariant = ""
                        , citationPrefix = [Italic [Plain "foo"]]
                        , citationSuffix = [Italic [Plain "baz"]]
                        , citationReferences = [ref]
                        }
        ]
    , "Targets" ~: target $
        [ "<<this is a target>>" =?> B.target "" "this is a target"
        , "<< not a target>>" =!> ()
        , "<<not a target >>" =!> ()
        , "<<this < is not a target>>" =!> ()
        , "<<this \n is not a target>>" =!> ()
        , "<<this > is not a target>>" =!> ()
        ]
    , "Math fragment" ~: latexFragment $
        [ "\\(\\LaTeX + 2\\)" =?> B.inlMath "\\LaTeX + 2"
        , "\\[\\LaTeX + 2\\]" =?> B.dispMath "\\LaTeX + 2"
        ]
    , "TeX Math Fragments" ~: plainMarkupContext texMathFragment $
        [ "$e = mc^2$" =?> B.inlMath "e = mc^2"
        , "$$foo bar$" =?> "$$foo bar$"
        , "$foo bar$a" =?> "$foo bar$a"
        , "($foo bar$)" =?> "(" <> B.inlMath "foo bar" <> ")"
        , "This is $1 buck, not math ($1! so cheap!)" =?> "This is $1 buck, not math ($1! so cheap!)"
        , "two$$always means$$math" =?> "two" <> B.dispMath "always means" <> "math"
        ]
    , "Subscripts and superscripts" ~: plainMarkupContext suscript $
        [ "not a _suscript" =?> "not a _suscript"
        , "not_{{suscript}" =?> "not_{{suscript}"
        , "a_{balanced^{crazy} ok}" =?> "a" <> B.subscript ("balanced" <> B.superscript "crazy" <> " ok")
        , "a_{balanced {suscript} ok}" =?> "a" <> B.subscript "balanced {suscript} ok"
        , "a_{bala\nnced {sus\ncript} ok}" =?> "a" <> B.subscript "bala\nnced {sus\ncript} ok"
        , "a^+strange,suscript," =?> "a" <> B.superscript "+strange,suscript" <> ","
        , "a^*suspicious suscript" =?> "a" <> B.superscript "*" <> "suspicious suscript"
        , "a_bad,.,.,maleficent, one" =?> "a" <> B.subscript "bad,.,.,maleficent" <> ", one"
        , "a_some\\LaTeX" =?> "a" <> B.subscript ("some" <> B.fragment "\\LaTeX")
        ]
    , "Line breaks" ~: plainMarkupContext linebreak $
        [ "this is a \\\\  \t\n\
          \line break"
            =?> "this is a "
            <> B.linebreak
            <> "line break"
        , "also linebreak \\\\" =?> "also linebreak " <> B.linebreak
        ]
    , "Image or links" ~: regularLink $
        [ "[[http://blablebli.com]]" =?> B.link (URILink "http" "//blablebli.com") mempty
        , "[[http://blablebli.com][/uh/ duh! *foo*]]" =?> B.link (URILink "http" "//blablebli.com") (B.italic "uh" <> " duh! " <> B.bold "foo")
        ]
    , "Statistic Cookies" ~: statisticCookie $
        [ "[13/18]" =?> B.statisticCookie (Left (13, 18))
        , "[33%]" =?> B.statisticCookie (Right 33)
        ]
    , "Footnote references" ~: footnoteReference $
        [ "[fn::simple]" =?> B.footnoteInlDef Nothing "simple"
        , "[fn::s[imple]" =!> ()
        , "[fn:mydef:s[imp]le]" =?> B.footnoteInlDef (Just "mydef") "s[imp]le"
        ]
    , "Macros" ~: macro $
        [ "{{{fooo()}}}" =?> B.macro "fooo" [""]
        , "{{{função()}}}" =!> ()
        , "{{{2fun()}}}" =!> ()
        , "{{{fun-2_3(bar,(bar,baz){a})}}}" =?> B.macro "fun-2_3" ["bar", "(bar", "baz){a}"]
        ]
    , "Italic" ~: italic $
        [ "// foo/" =?> B.italic "/ foo"
        , "/foo //" =?> B.italic "foo /"
        , "/foo / f/" =?> B.italic "foo / f"
        ]
    ]
