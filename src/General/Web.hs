{-# LANGUAGE PatternGuards #-}

{- |
    General web utility functions.
-}

module General.Web(
    responseOk, responseBadRequest, responseNotFound, responseError,
    URL, filePathToURL, combineURL, escapeURL, (++%), unescapeURL,
    escapeHTML, (++&), htmlTag,
    Args, cgiArgs, parseHttpQueryArgs
    ) where

import General.System
import General.Base
import Network.HTTP

instance Functor Response where
    fmap f x = x{rspBody = f $ rspBody x}


responseOk = Response (2,0,0) "OK"
responseBadRequest x = Response (4,0,0) "Bad Request" [] $ "Bad request: " ++ x
responseNotFound x = Response (4,0,4) "Not Found" [] $ "File not found: " ++ x
responseError x = Response (5,0,0) "Internal Server Error" [] $ "Internal server error: " ++ x


type Args = [(String, String)]


---------------------------------------------------------------------
-- HTML STUFF

-- | Take a piece of text and escape all the HTML special bits
escapeHTML :: String -> String
escapeHTML = concatMap f
    where
        f '<' = "&lt;"
        f '>' = "&gt;"
        f '&' = "&amp;"
        f  x  = [x]


-- | Escape the second argument as HTML before appending
(++&) :: String -> String -> String
a ++& b = a ++ escapeHTML b


htmlTag :: String -> String -> String
htmlTag x y = "<" ++ x ++ ">" ++ y ++ "</" ++ x ++ ">"


---------------------------------------------------------------------
-- URL STUFF

filePathToURL :: FilePath -> URL
filePathToURL xs = "file://" ++ ['/' | not $ "/" `isPrefixOf` ys] ++ ys
    where ys = map (\x -> if isPathSeparator x then '/' else x) xs


combineURL :: String -> String -> String
combineURL a b
    | any (`isPrefixOf` b) ["http:","https:","file:"] = b
    | otherwise = a ++ b


-- | Take an escape encoded string, and return the original
unescapeURL :: String -> String
unescapeURL ('+':xs) = ' ' : unescapeURL xs
unescapeURL ('%':a:b:xs) | [(v,"")] <- readHex [a,b] = chr v : unescapeURL xs
unescapeURL (x:xs) = x : unescapeURL xs
unescapeURL [] = []


escapeURL :: String -> String
escapeURL = concatMap f
    where
        f x | isAlphaNum x || x `elem` "-" = [x]
            | x == ' ' = "+"
            | otherwise = '%' : ['0'|length s == 1] ++ s
            where s = showHex (ord x) ""


-- | Escape the second argument as a CGI query string before appending
(++%) :: String -> String -> String
a ++% b = a ++ escapeURL b

---------------------------------------------------------------------
-- CGI STUFF

-- The BOA server does not set QUERY_STRING if it would be blank.
-- However, it does always set REQUEST_URI.
cgiVariable :: IO (Maybe String)
cgiVariable = do
    str <- getEnvVar "QUERY_STRING"
    if isJust str
        then return str
        else fmap (fmap $ const "") $ getEnvVar "REQUEST_URI"


cgiArgs :: IO (Maybe Args)
cgiArgs = do
    x <- cgiVariable
    return $ case x of
        Nothing -> Nothing
        Just y -> Just $ parseHttpQueryArgs $ ['=' | '=' `notElem` y] ++ y


---------------------------------------------------------------------
-- HTTP STUFF

parseHttpQueryArgs :: String -> Args
parseHttpQueryArgs xs = mapMaybe (f . splitPair "=") $ splitList "&" xs
    where f Nothing = Nothing
          f (Just (a,b)) = Just (unescapeURL a, unescapeURL b)


splitList :: Eq a => [a] -> [a] -> [[a]]
splitList find str = if isJust q then a : splitList find b else [str]
    where
        q = splitPair find str
        Just (a, b) = q


splitPair :: Eq a => [a] -> [a] -> Maybe ([a], [a])
splitPair find str = f str
    where
        f [] = Nothing
        f x  | isPrefixOf find x = Just ([], drop (length find) x)
             | otherwise = if isJust q then Just (head x:a, b) else Nothing
                where
                    q = f (tail x)
                    Just (a, b) = q
