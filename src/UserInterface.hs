module UserInterface where

import System.IO (hPutStrLn, stderr)

-- TODO: Add colors etc

writeMessage :: String -> IO ()
writeMessage = hPutStrLn stderr

writeWarning :: String -> IO ()
writeWarning = hPutStrLn stderr

writeError :: String -> IO ()
writeError = hPutStrLn stderr

writeOutput :: String -> IO ()
writeOutput = putStrLn
