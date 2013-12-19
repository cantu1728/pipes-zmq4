module Main
where

import Pipes
import qualified Pipes.Prelude as P
import qualified Pipes.ZMQ4 as PZ
import qualified System.ZMQ4 as Z
import qualified Data.ByteString.Char8 as BC
import Control.Concurrent (threadDelay, forkIO)
import Control.Monad (forever)

main :: IO ()
main = do
    -- create and use exactly one context in a single process
    Z.withContext $ \ctx ->
        Z.withSocket ctx Z.Rep $ \echoServer ->
        Z.withSocket ctx Z.Req $ \client -> do
            
            Z.bind echoServer "inproc://echoserver"
            forkIO $ echo echoServer
            putStrLn "Started echo server"

            Z.connect client "inproc://echoserver"
            putStrLn "The client will send stdout to the echoserver and print it back"
            runEffect $ P.stdinLn >-> P.map (BC.pack) >-> PZ.request client >-> P.map (BC.unpack) >-> P.stdoutLn
    where
        echo s =
            forever $ do
                msg <- Z.receive s
                -- Simulate doing some 'work' for 1 second
                threadDelay (1000000)
                Z.send s [] msg

