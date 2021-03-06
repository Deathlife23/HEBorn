module UI.DynStyles.Highlight.OS exposing (..)

import Css exposing (..)
import Css.Namespace exposing (namespace)
import Css.Utils as Css exposing (withAttribute, nest)
import Utils.Html.Attributes exposing (activeContextValue, appAttrTag)
import Game.Meta.Types.Context exposing (Context)
import OS.Resources as OS
import OS.SessionManager.Dock.Resources as Dock
import OS.SessionManager.WindowManager.Resources as WM
import Apps.Models as Apps
import Apps.Apps exposing (App)


highlightDockIcon : App -> Stylesheet
highlightDockIcon app =
    (stylesheet << namespace Dock.prefix)
        [ class Dock.ItemIco
            [ withAttribute (Css.EQ Dock.appIconAttrTag (Apps.icon app))
                [ borderRadius (px 0) |> important
                , backgroundImage none |> important
                , backgroundColor (hex "F00")
                ]
            ]
        ]


highlightHeaderContextToggler : Context -> Stylesheet
highlightHeaderContextToggler context =
    (stylesheet << namespace OS.prefix)
        [ class OS.Context
            [ withAttribute (Css.NOT (Css.BOOL OS.headerContextActiveAttrTag))
                [ backgroundColor (hex "F00") ]
            ]
        ]


highlightWindow : App -> Context -> Stylesheet
highlightWindow app context =
    (stylesheet << namespace WM.prefix)
        [ class WM.Window
            [ nest
                [ withAttribute (Css.EQ appAttrTag (Apps.name app))
                , context
                    |> activeContextValue
                    |> Css.EQ "context"
                    |> withAttribute
                ]
                [ backgroundColor (hex "F00") ]
            ]
        ]
