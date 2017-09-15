module Apps.Browser.Pages.NoWebserver.Models
    exposing
        ( Model
        , initialModel
        , getTitle
        )

import Game.Network.Types as Network
import Game.Web.Types exposing (Url, NoWebserverMetadata)
import Game.Web.Types as Web exposing (Site)


type alias Model =
    { password : Maybe String
    , url : Url
    }



-- Default page for valid IP without a server


initialModel : Url -> NoWebserverMetadata -> Model
initialModel url meta =
    { password = meta.password
    , url = url
    }


getTitle : Model -> String
getTitle { url } =
    "Accessing " ++ url