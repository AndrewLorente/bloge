{-# LANGUAGE OverloadedStrings #-}

------------------------------------------------------------------------------
-- | This module is where all the routes and handlers are defined for your
-- site. The 'app' function is the initializer that combines everything
-- together and is exported by this module.
module Site
  ( app
  ) where

------------------------------------------------------------------------------
import           Control.Lens        (set)
import           Data.ByteString     (ByteString)
import           Snap.Snaplet
import           Snap.Snaplet.Heist
import           Snap.Util.FileServe
import           Snap.Core           (method, Method(..), ifTop)
import           Heist
------------------------------------------------------------------------------
import           Application
import           Splices        (currentPath)
import           Document
import           Document.Heist

index :: Handler App App ()
index = method GET $ render "index"

atom :: Handler App App ()
atom = method GET $ renderAs "application/atom+xml" "atom"

routes :: [(ByteString, Handler App App ())]
routes = [ ("/",           ifTop index)
         , ("/posts.atom", atom)
         , ("/static",     serveDirectory "static")
         ]

app :: [Document] -> SnapletInit App App
app docs = makeSnaplet "bloge" "Such posts, many tags, very markdown" Nothing $ do
    h <- nestSnaplet "" heist $ heistInit "templates"
    let localSplices = do
        "currentPath" ## currentPath
        "posts" ## (bindDocuments docs)
        "latestPost" ## (postedSplice $ head docs)
    let heistConfig = set scInterpretedSplices localSplices $
                      set scInterpretedSplices defaultInterpretedSplices $
                      mempty
    addRoutes routes
    addRoutes $ documentRoutes docs
    addRoutes $ tagRoutes docs
    addConfig h heistConfig
    return $ App h

