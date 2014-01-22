{-# LANGUAGE RankNTypes, OverloadedStrings #-}

module Main
where

import Control.Concurrent(threadDelay)
import Control.Concurrent.Async
import Control.Monad (forever, unless)
import Control.Applicative((<$>), (<*>))
import Control.Lens(zoom)
import qualified Control.Foldl as L
import qualified Data.ByteString.Char8 as BC
import Data.Monoid((<>))
import Pipes
import Pipes.Parse (Parser, isEndOfInput, evalStateT)
import qualified Pipes.Parse as PP
import qualified Pipes.ZMQ4 as PZ
import Text.Printf
import System.Random (randomRIO)
import qualified System.ZMQ4 as Z

zipCode = "10001"

pubServerThread :: Z.Sender t => Z.Socket t -> IO r
pubServerThread s = forever $ do
    threadDelay (10) -- be gentle with the CPU
    zipcode <- randomRIO (10000::Int, 11000)
    temperature <- randomRIO (-10::Int, 35)
    humidity <- randomRIO (10::Int, 60)
    let update = BC.pack $ unwords [show zipcode, show temperature, show humidity]
    Z.send s [] update

bogusServerThread :: Z.Sender t => Z.Socket t -> IO r
bogusServerThread s = forever $ do
    threadDelay (5 * 1000 * 1000)
    let bogusMsg = zipCode <> " 10 bogus"
    Z.send s [] bogusMsg

average :: L.Fold Int Int
average = div <$> L.sum <*> L.length

main :: IO ()
main = do
    -- create and use exactly one context in a single process
    Z.withContext $ \ctx ->
        Z.withSocket ctx Z.Pub $ \pubSocket ->
        Z.withSocket ctx Z.Sub $ \subSocket -> do

            Z.bind pubSocket "inproc://pubserver"
            putStrLn "Starting pub server"
            async $ pubServerThread pubSocket
            async $ bogusServerThread pubSocket

            Z.connect subSocket "inproc://pubserver"
            Z.subscribe subSocket zipCode

            evalStateT reportParser (processedData subSocket)
    where

        reportParser :: Parser (Int, Int) IO ()
        reportParser = loop
            where
                loop = do
                    (avgTemp, avgHum) <- zoom (PP.splitAt 10) (L.purely PP.foldAll averages)
                    liftIO $ printf "-- Report: average temperature is %d°C, average humidity is %d%% \n" avgTemp avgHum
                    eof <- isEndOfInput
                    unless eof loop

        averages :: L.Fold (Int, Int) (Int, Int)
        averages =
            let avgTemp :: L.Fold (Int, Int) Int
                avgTemp = L.premap fst average

                avgHumidity :: L.Fold (Int, Int) Int
                avgHumidity = L.premap snd average

            in  (,) <$> avgTemp <*> avgHumidity

        processedData :: Z.Socket Z.Sub -> Producer (Int, Int) IO ()
        processedData subSocket = for (PZ.fromZMQ subSocket) $ \bs -> do
            case map BC.readInt (BC.words bs) of
                [_, Just (temp, _), Just(hum, _)] -> do
                    liftIO $ printf "At NY City, temperature of %d and humidity %d\n"  temp hum
                    yield (temp, hum)
                [_, _, _]                         -> do
                    liftIO $ putStrLn "BOGUS - Ignore"
                    return()





