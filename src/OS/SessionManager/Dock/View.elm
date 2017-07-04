module OS.SessionManager.Dock.View exposing (view)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Events exposing (onClick)
import Html.Attributes exposing (attribute)
import Html.CssHelpers
import OS.Resources as OsRes
import OS.SessionManager.Models as SessionManager exposing (..)
import OS.SessionManager.Dock.Messages exposing (..)
import OS.SessionManager.Dock.Resources as Res
import OS.SessionManager.WindowManager.Models as WindowManager
import OS.SessionManager.WindowManager.View exposing (windowTitle)
import Apps.Models as Apps
import Apps.Apps as Apps
import Game.Data as GameData


-- this module still needs a refactor to make its code more maintainable


{ id, class, classList } =
    Html.CssHelpers.withNamespace Res.prefix


osClass : List class -> Attribute msg
osClass =
    .class <| Html.CssHelpers.withNamespace OsRes.prefix


view : GameData.Data -> SessionManager.Model -> Html Msg
view game model =
    div
        [ osClass [ OsRes.Dock ] ]
        [ dock game model
        ]



-- internals


{-| this is messy until elm compiler issue 1008 gets fixed
-}
type alias Applications =
    Dict String ( Apps.App, List WindowRef )


getApplications : GameData.Data -> SessionManager.Model -> Applications
getApplications data model =
    -- This function should create an app list from the current
    -- server "list of apps" and also from session windows
    List.foldl
        (\app dict ->
            let
                refs =
                    windows data app model
            in
                Dict.insert (Apps.name app) ( app, refs ) dict
        )
        Dict.empty
        data.game.account.dock


windows : GameData.Data -> Apps.App -> Model -> List WindowRef
windows data app model =
    case get data.id model of
        Just wm ->
            wm.windows
                |> WindowManager.filterAppWindows app
                |> Dict.toList
                |> List.map (\( id, win ) -> ( data.id, id ))

        Nothing ->
            []


hasInstance : List a -> String
hasInstance list =
    if ((List.length list) > 0) then
        "Y"
    else
        "N"


apps : GameData.Data -> Model -> List ( String, ( Apps.App, List WindowRef ) )
apps game model =
    model
        |> getApplications game
        |> Dict.toList


dock : GameData.Data -> Model -> Html Msg
dock game model =
    div [ class [ Res.Container ] ]
        [ div
            [ class [ Res.Main ] ]
            (model |> apps game |> List.map (format >> icon model))
        ]


format : ( a, ( b, c ) ) -> ( a, b, c )
format ( name, ( app, list ) ) =
    ( name, app, list )


icon : Model -> ( a, Apps.App, List WindowRef ) -> Html Msg
icon model ( name, app, list ) =
    div
        [ class [ Res.Item ]
        , attribute "data-hasinst" (hasInstance list)
        ]
        ([ div
            [ class [ Res.ItemIco ]
            , onClick (openOrRestore app list)
            , attribute "data-icon" (Apps.icon app)
            ]
            []
         ]
            ++ (if not (List.isEmpty list) then
                    [ subMenu app list model ]
                else
                    []
               )
        )


openOrRestore : Apps.App -> a -> Msg
openOrRestore app list =
    -- FIXME pls
    OpenApp app


subMenu : Apps.App -> List WindowRef -> Model -> Html Msg
subMenu app refs model =
    div
        [ class [ Res.AppContext ]
        ]
        [ ul []
            ((openedWindows app refs model)
                ++ [ hr [] [] ]
                ++ (minimizedWindows app refs model)
                ++ [ hr [] [] ]
                ++ [ subMenuAction "New window" (OpenApp app)
                   , subMenuAction "Minimize all" (MinimizeApps app)
                   , subMenuAction "Close all" (CloseApps app)
                   ]
            )
        ]


subMenuAction : String -> msg -> Html msg
subMenuAction label event =
    li
        [ class [ Res.ClickableWindow ], onClick event ]
        [ text label ]


openedWindows : a -> List WindowRef -> Model -> List (Html Msg)
openedWindows app refs model =
    let
        -- this function only exists because unions are'nt composable
        filter =
            \state ->
                case state of
                    WindowManager.NormalState ->
                        True

                    _ ->
                        False

        wins =
            refs
                |> filterWinState filter app model
                |> windowList model FocusWindow
    in
        (li [] [ text "OPEN WINDOWS" ]) :: wins


minimizedWindows : a -> List WindowRef -> Model -> List (Html Msg)
minimizedWindows app refs model =
    let
        -- this function only exists because unions are'nt composable
        filter =
            \state ->
                case state of
                    WindowManager.MinimizedState ->
                        True

                    _ ->
                        False

        wins =
            refs
                |> filterWinState filter app model
                |> windowList model RestoreWindow
    in
        (li [] [ text "MINIMIZED LINUXES" ]) :: wins


windowLabel : Int -> WindowRef -> Model -> String
windowLabel i refs model =
    (toString i)
        ++ ": "
        ++ (refs
                |> (flip getWindow) model
                |> Maybe.andThen (windowTitle >> Just)
                |> Maybe.withDefault "404"
           )


windowList : Model -> (WindowRef -> msg) -> List WindowRef -> List (Html msg)
windowList model event =
    List.indexedMap
        (\i (( sID, id ) as refs) ->
            li
                [ class [ Res.ClickableWindow ]
                , attribute "data-id" id
                , onClick (event refs)
                ]
                [ text (windowLabel i refs model) ]
        )


filterWinState :
    (WindowManager.WindowState -> Bool)
    -> a
    -> Model
    -> List WindowRef
    -> List ( String, String )
filterWinState filter app model =
    List.filter
        (\ref ->
            case getWindow ref model of
                Just win ->
                    filter win.state

                Nothing ->
                    False
        )
