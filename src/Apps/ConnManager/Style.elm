module Apps.ConnManager.Style exposing (..)

import Css exposing (..)
import Css.Namespace exposing (namespace)
import Css.Icons as Icon
import UI.Colors as Colors
import Apps.ConnManager.Resources exposing (Classes(..), prefix)


ico : Style
ico =
    before
        [ Icon.fontFamily
        , textAlign center
        ]


css : Stylesheet
css =
    (stylesheet << namespace prefix)
        [ class IcoUp
            [ ico
            , before [ Icon.upload ]
            ]
        , class IcoDown
            [ ico
            , before [ Icon.download ]
            ]
        , class GroupedTunnel
            [ borderBottom3 (px 1) solid Colors.black
            ]
        ]
