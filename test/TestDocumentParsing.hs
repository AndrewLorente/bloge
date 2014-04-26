{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}

module TestDocumentParsing (testGroups) where

import           Test.Framework                 (testGroup)
import           Test.Framework.Providers.HUnit
import           Test.HUnit
import           Data.List                      (sort, intercalate)
import           Data.Maybe                     (fromJust)
import           Data.Time.ISO8601              (parseISO8601)
import           Document
import           Document.Internal              (posted, body, slug, slugify)
import qualified Text.Parsec                    as P
import qualified Text.Parsec.Error              as P
import qualified Text.Parsec.Pos                as P
deriving instance Show P.Message

testGroups = [
    testGroup "Successful document parsing" [
      testCase "parse a simple document" test_parse_simple_doc
    , testCase "Tag declaration may be omitted" test_omit_tag_field
    , testCase "declarations can be in any order" test_parse_in_any_order
    , testCase "infer the slug from the title" test_infer_slug_from_title
    , testCase "markdown in the body is rendered as html" test_render_markdown
    ]
  , testGroup "Field parsing errors" [
      testCase "date-time validation" test_fail_datetime_validation
    , testCase "slug validation" test_slug_character_restriction
    ]
  , testGroup "slugification" [
      testCase "lowercases words" test_slugify_lowercases_words
    , testCase "replaces spaces with hyphens" test_slugify_hyphenates_spaces
    , testCase "strips nonalphanumerics" test_slugify_strips_nonalphanumerics
    ]
  ]

test_parse_simple_doc = do
    let parseResult = parse $ intercalate "\n" [
            "Title: Whoa Mama!"
          , "Slug: whoa-mama"
          , "Posted: 2014-03-28T06:50:30-0700"
          , "Tags:"
          , "    partying"
          , "    drinkin'"
          , "    socializing"
          , "Party at my place!"
          , "We will have fun."
          , ""
          ]
        doc = Document {
            dTitle = "Whoa Mama!"
          , dSlug = "whoa-mama"
          , dPosted = (fromJust $ parseISO8601 "2014-03-28T13:50:30Z")
          , dTags = ["partying", "drinkin'", "socializing"]
          , dBody = "<p>Party at my place!\nWe will have fun.</p>"
        }

    parseResult @?= (Right doc)

test_omit_tag_field = do
    let parseResult = parse $ intercalate "\n" [
            "Title: Hanes T-Shirts Don't Have Tags"
          , "Slug: hanes-t-shirts-dont-have-tags"
          , "Posted: 2014-03-28T06:50:30-0700"
          , "Honestly I'm not sure it's all that important"
          , ""
          ]
        doc = Document {
            dTitle = "Hanes T-Shirts Don't Have Tags"
          , dSlug = "hanes-t-shirts-dont-have-tags"
          , dPosted = (fromJust $ parseISO8601 "2014-03-28T13:50:30Z")
          , dTags = []
          , dBody = "<p>Honestly I&#39;m not sure it&#39;s all that important</p>"
        }

    parseResult @?= (Right doc)

test_parse_in_any_order = do
    let parseResult = parse $ intercalate "\n" [
            "Posted: 2014-03-28T06:50:30-0700"
          , "Title: I'm a friggin rebel"
          , "Tags:"
          , "Slug: any-order-i-want"
          , "You can't pin me down with your REGULATIONS"
          , ""
          ]
        doc = Document {
            dTitle = "I'm a friggin rebel"
          , dSlug = "any-order-i-want"
          , dPosted = (fromJust $ parseISO8601 "2014-03-28T13:50:30Z")
          , dTags = []
          , dBody = "<p>You can&#39;t pin me down with your REGULATIONS</p>"
        }

    parseResult @?= (Right doc)

test_infer_slug_from_title = do
    let parseResult = parse $ intercalate "\n" [
              "Title: This! Is! Spartaaaaaa!"
            , "Posted: 2014-03-28T06:50:30-0700"
            , "Tags:"
            , "Madness?"
            , "<img src='https://d5hwde6hzncg6.cloudfront.net/df0e2fa0dfbce52b75bdba41caf01a9551881237' />"
            , ""
            ]
        doc = Document {
            dTitle = "This! Is! Spartaaaaaa!"
          , dSlug = "this-is-spartaaaaaa"
          , dPosted = (fromJust $ parseISO8601 "2014-03-28T13:50:30Z")
          , dTags = []
          , dBody = "<p>Madness?\n<img src='https://d5hwde6hzncg6.cloudfront.net/df0e2fa0dfbce52b75bdba41caf01a9551881237' /></p>"
        }

    parseResult @?= (Right doc)

test_render_markdown = do
  let parseResult = P.parse body "" "[click here for wonder](https://andrewlorente.com)\n"

  parseResult @?= (Right "<p><a href=\"https://andrewlorente.com\">click here for wonder</a></p>")


test_fail_datetime_validation = do
  let result = P.parse posted "" "Posted: March 15\n"
  result @?= err "Posted date must be an ISO 8601 datetime"
    where
      err msg = Left $
          P.newErrorMessage (P.UnExpect msg) (P.newPos "" 0 0)

test_slug_character_restriction = do
  let result = P.parse slug "" "Slug: I Hate Clean URLs!\n"
      firstError = P.newErrorMessage (P.SysUnExpect "\" \"") (P.newPos "" 1 8)
      errors = foldl (flip P.addErrorMessage) firstError [
              P.SysUnExpect "\" \""
            , P.SysUnExpect "\" \""
            , P.SysUnExpect "\" \""
            , P.Expect "URL-friendly string: alphanumerics, -, or _"
            , P.Expect "\"\\n\""
            ]
  result @?= Left errors

test_slugify_lowercases_words = do
  slugify "LeElOoDaLlAsMuLtIcAsE" @?= "leeloodallasmulticase"

test_slugify_hyphenates_spaces = do
  slugify "in space no-one can hear you scream" @?= "in-space-no-one-can-hear-you-scream"

test_slugify_strips_nonalphanumerics = do
  slugify "1!ü_" @?= "1_"

instance Eq P.ParseError where
  a == b = (length aMsgs) == (length bMsgs) &&
                             (and $ zipWith eq (sort aMsgs) (sort bMsgs))
    where
      aMsgs = P.errorMessages a
      bMsgs = P.errorMessages b
      eq :: P.Message -> P.Message -> Bool
      x `eq` y = x == y && P.messageString x == P.messageString y
