module Main
where

import Pipes
import qualified Pipes.Prelude as P
import qualified Pipes.ZMQ3 as PZ
import qualified System.ZMQ3 as Z

import Control.Concurrent(threadDelay)
import Control.Concurrent.Async
import Control.Monad (forever)
import Data.ByteString.Char8 (pack, unpack)
import System.Random (randomRIO)


main :: IO ()
main = do
    -- create and use exactly one context in a single process
    Z.withContext $ \ctx ->
        Z.withSocket ctx Z.Pub $ \pubSocket ->
        Z.withSocket ctx Z.Sub $ \subSocket -> do
            
            Z.bind pubSocket "inproc://pubserver"
            putStrLn "Starting pub server"
            async $ pubServer pubSocket
            Z.connect subSocket "inproc://pubserver"
            Z.subscribe subSocket (pack "10001")
            runEffect $ PZ.fromSub subSocket >-> P.map (display.words.unpack) >->  P.stdout
    where
        
        pubServer s = forever $ do
            threadDelay (29) -- be gentle with the CPU
            zipcode <- randomRIO (10000::Int, 19900) -- be gentle with the CPU
            temperature <- randomRIO (-10::Int, 35)
            humidity <- randomRIO (10::Int, 60)
            let update = pack $ unwords [show zipcode, show temperature, show humidity]
            Z.send s [] update
        
        display:: [String] -> String
        display [_, temp, hum] =
            unwords ["NY City", "Temperature:" , temp, "Humidity:" , hum] 
