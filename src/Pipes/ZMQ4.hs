{-# LANGUAGE RankNTypes #-}

module Pipes.ZMQ4 (
	  fromZMQ
    , request
    ) where

import Control.Monad (forever)
import Data.ByteString(ByteString)
import Pipes
import qualified System.ZMQ4 as Z


{-| Send upstream bytes into a request socket,
    wait/block and yield the reply
-}
request :: MonadIO m => Z.Socket Z.Req -> Pipe ByteString ByteString m ()
request sock = for cat $ \b -> do
    rep <- liftIO (Z.send sock [] b >> Z.receive sock)
    yield rep

{-| Wait for a msg from a receiver 'Z.Socket' and yield it
    Empty bytestrings are passed along as any other bytes
-}
fromZMQ :: (MonadIO m, Z.Receiver t)  => Z.Socket t -> Producer' ByteString m ()
fromZMQ sock  = forever $ do
    bs <- liftIO (Z.receive sock)
    yield bs