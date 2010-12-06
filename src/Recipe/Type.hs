
module Recipe.Type(
    CmdLine(..), Name, hoo, noDeps,
    keywords, platform, cabals, haddocks, listing, version,
    resetErrors, putError, recapErrors,
    Cabal(..), readCabal, readCabalDepends, readCabalField
    ) where

import CmdLine.All
import Data.IORef
import System.IO.Unsafe
import General.Code
import Data.Function


type Name = String

hoo :: Name -> FilePath
hoo x = x <.> "hoo"


noDeps :: Name -> IO ()
noDeps = error "Internal error: package with no dependencies had dependencies"


---------------------------------------------------------------------
-- DOWNLOADED INFORMATION

keywords = "download/keyword.txt"
platform = "download/haskell-platform.cabal"
cabals = "download/hackage-cabal"
haddocks = "download/hackage-haddock"

listing :: FilePath -> IO [Name]
listing dir = do
    xs <- getDirectoryContents dir
    return $ sortBy (compare `on` map toLower) $ filter (`notElem` [".","..","preferred-versions"]) xs

version :: FilePath -> Name -> IO String
version dir x = do
    ys <- getDirectoryContents $ dir </> x
    when (null ys) $ error $ "Couldn't find version for " ++ x ++ " in " ++ dir
    let f = map (read :: String -> Int) . words . map (\x -> if x == '.' then ' ' else x)
    return $ maximumBy (compare `on` f) $ filter (all (not . isAlpha)) ys


---------------------------------------------------------------------
-- ERROR MESSAGES

{-# NOINLINE errors #-}
errors :: IORef [String]
errors = unsafePerformIO $ newIORef []

putError :: String -> IO ()
putError x = do
    putStrLn x
    modifyIORef errors (x:)

recapErrors :: IO ()
recapErrors = do
    xs <- readIORef errors
    mapM_ putStrLn $ reverse xs

resetErrors :: IO ()
resetErrors = writeIORef errors []


---------------------------------------------------------------------
-- CABAL

data Cabal = Cabal {cabalDepends :: [String], cabalDescription :: [String]}

readCabal :: FilePath -> IO Cabal
readCabal file = do
    src <- fmap lines $ readFile' file
    return $ Cabal (readCabalDepends src) (readCabalField src True "description")


readCabalDepends :: [String] -> [String]
readCabalDepends xs = nub $ map (takeWhile g) $ filter f $ words $ map (rep ',' ' ') $ unwords $ readCabalField xs False "build-depends"
    where f x = x /= "" && isAlpha (head x)
          g x = isAlphaNum x || x `elem` "-_"


readCabalField :: [String] -> Bool -> String -> [String]
readCabalField xs root name = f xs
    where
        f (x:xs) | (name ++ ":") `isPrefixOf` map toLower x2 && (null spc || not root) =
                [x4 | x4 /= []] ++ map (rep "." "" . trim) ys ++ f zs
            where
                x4 = trim x3
                x3 = drop (length name + 1) x2
                (spc,x2) = span isSpace x
                (ys,zs) = span ((> length spc) . length . takeWhile isSpace) xs
        f (x:xs) = f xs
        f [] = []
