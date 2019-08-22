-- file: Homer.hs

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Homer where

-- Json
import Data.Aeson
import Data.Map as Map
import Data.Maybe

import GHC.Generics

-- Socket
import Network.Socket
import System.IO
import Data.ByteString.Lazy
import Data.ByteString.Lazy.Internal as BI
import Data.Text as Text
import Network.Socket.ByteString as BS

data Homer = Homer { rSocket :: Socket, rAddr :: SockAddr }

data Letter = Letter { ident :: String, content :: Map String String }

instance ToJSON Letter where
  toJSON (Letter ident content) =
    object ["ident" .= ident, "content" .= content]

instance FromJSON Letter where
  parseJSON = withObject "Letter" $ \v -> Letter
    <$> v .: "ident"
    <*> v .: "content"

emptyLetter :: Letter
emptyLetter = Letter "" Map.empty

letterUpdate :: Letter
             -> String -- Key
             -> String -- New value
             -> Letter
letterUpdate l k nv =
  Letter (ident l) (updateWithKey (\k_ v_ -> Just nv) k (content l))

pickHomer :: String -- HostName
        -> String -- Port
        -> IO Homer
pickHomer host port = do
  addrInfos <- getAddrInfo Nothing (Just host) (Just port)

  let serverAddr = Prelude.head addrInfos
  sock <- socket (addrFamily serverAddr) Datagram defaultProtocol
  setSocketOption sock KeepAlive 1

  return $ Homer sock (addrAddress serverAddr)

letterBuild :: Letter -> ByteString
letterBuild l = encode $ Letter (ident l) (content l)

homerFlyWith :: Homer -> Letter -> IO ()
homerFlyWith homer letter =
  BS.sendTo (rSocket homer) (toStrict $ letterBuild letter) (rAddr homer) >> return ()

waitHomer :: Homer -> IO Letter
waitHomer homer = do
  (rawLetter_, addr) <- BS.recvFrom (rSocket homer) 1024

  let letter = (decode $ fromStrict rawLetter_ :: Maybe Letter)
  if isNothing letter
    then return $ emptyLetter
    else return $ fromJust letter
