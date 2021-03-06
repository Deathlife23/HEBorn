module Game.Storyline.DynamicStyle exposing (dynCss)

import Css exposing (Stylesheet)
import Game.Storyline.Models exposing (Model)
import UI.DynStyles.SimplePlan.Apps exposing (..)
import UI.DynStyles.Hide.OS exposing (..)
import UI.DynStyles.Show.OS exposing (..)
import Apps.Apps exposing (..)


dynCss : Model -> List Stylesheet
dynCss model =
    [ simpleBrowser
    , hideAllDock
    , showDockIcon BrowserApp
    , showDockIcon EmailApp
    ]
