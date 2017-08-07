module Game.Servers.Logs.Messages exposing (Msg(..), RequestMsg(..))

import Json.Decode exposing (Value)
import Game.Servers.Logs.Models exposing (ID, StdData)
import Requests.Types exposing (ResponseType)


type Msg
    = BootstrapLogs Value
    | UpdateContent ID String
    | Crypt ID
    | Uncrypt ID String
    | Hide ID
    | Unhide StdData
    | Delete ID
    | Request RequestMsg


type RequestMsg
    = LogIndexRequest ResponseType
