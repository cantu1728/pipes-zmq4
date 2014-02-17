{-# LANGUAGE OverloadedStrings #-}
module Main
where

import           Control.Concurrent    (forkIO, threadDelay)
import           Control.Monad         (forever)
import qualified Data.ByteString.Char8 as BC
import           Data.Monoid           ((<>))
import           Pipes
import qualified Pipes.Prelude         as P
import qualified Pipes.ZMQ4            as PZ
import qualified System.ZMQ4           as Z

main :: IO ()
main = do
    -- create and use exactly one context in a single process
    Z.withContext $ \ctx ->
        Z.withSocket ctx Z.Rep $ \echoSocket ->
        Z.withSocket ctx Z.Req $ \client -> do

            Z.bind echoSocket "inproc://echoserver"
            forkIO $ echo echoSocket
            putStrLn "Started echo server"

            Z.connect client "inproc://echoserver"
            putStrLn "The client will send stdout to the echoserver and print it back"
            runEffect $ P.stdinLn >-> P.map (BC.pack) >-> PZ.request client >-> P.map (BC.unpack) >-> P.stdoutLn
    where
        echo sock =
            forever $ do
                msg <- Z.receive sock
                -- Simulate doing some 'work' for 1 second
                threadDelay (1 * 1000)
                Z.send sock [] (msg <> " from the echo server")

