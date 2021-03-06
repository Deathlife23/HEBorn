module Apps.Finance.Style exposing (..)

import Css exposing (..)
import Css.Elements exposing (div)
import Css.Namespace exposing (namespace)
import UI.Colors as Colors
import Apps.Finance.Resources exposing (Classes(..), prefix)


css : Stylesheet
css =
    (stylesheet << namespace prefix)
        [ class FinanceEntry
            [ displayFlex
            , padding2 (px 4) (px 6)
            , children
                [ everything
                    [ display inlineBlock ]
                , class RightSide
                    []
                , class LeftSide
                    [ alignSelf flexStart
                    , flex (int 1)
                    ]
                ]
            ]
        ]
