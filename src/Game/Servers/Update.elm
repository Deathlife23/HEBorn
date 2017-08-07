module Game.Servers.Update exposing (..)

import Json.Decode as Decode exposing (Value)
import Core.Dispatch as Dispatch exposing (Dispatch)
import Game.Messages as Game
import Game.Models as Game
import Game.Servers.Filesystem.Messages as Filesystem
import Game.Servers.Filesystem.Models as Filesystem
import Game.Servers.Filesystem.Update as Filesystem
import Game.Servers.Logs.Messages as Logs
import Game.Servers.Logs.Models as LogsModel
import Game.Servers.Logs.Update as Logs
import Game.Servers.Messages exposing (..)
import Game.Servers.Models exposing (..)
import Game.Servers.Processes.Messages as Processes
import Game.Servers.Processes.Models as Processes
import Game.Servers.Processes.Update as Processes
import Game.Servers.Requests exposing (..)
import Game.Servers.Shared exposing (..)
import Game.Servers.Tunnels.Messages as Tunnels
import Game.Servers.Tunnels.Models as Tunnels
import Game.Servers.Tunnels.Update as Tunnels
import Game.Servers.Requests.Server as Server


update :
    Game.Model
    -> Msg
    -> Model
    -> ( Model, Cmd Game.Msg, Dispatch )
update game msg model =
    case msg of
        FilesystemMsg id msg ->
            filesystem game id msg model

        LogMsg id msg ->
            log game id msg model

        ProcessMsg id msg ->
            process game id msg model

        TunnelsMsg id msg ->
            tunnel game id msg model

        Request data ->
            response game (receive data) model

        SetBounce id bounce ->
            let
                model_ =
                    model
                        |> get id
                        |> Maybe.map (setBounce bounce)
                        |> Maybe.map (flip (insert id) model)
                        |> Maybe.withDefault model
            in
                ( model_, Cmd.none, Dispatch.none )

        SetEndpoint id endpoint ->
            let
                model_ =
                    model
                        |> get id
                        |> Maybe.map (setEndpoint endpoint)
                        |> Maybe.map (flip (insert id) model)
                        |> Maybe.withDefault model
            in
                ( model_, Cmd.none, Dispatch.none )

        BootstrapServers json ->
            bootstrap game json model

        _ ->
            ( model, Cmd.none, Dispatch.none )



-- internals


response :
    Game.Model
    -> Response
    -> Model
    -> ( Model, Cmd Game.Msg, Dispatch )
response response game model =
    case response of
        _ ->
            ( model, Cmd.none, Dispatch.none )


filesystem :
    Game.Model
    -> ID
    -> Filesystem.Msg
    -> Model
    -> ( Model, Cmd Game.Msg, Dispatch )
filesystem game id msg model =
    case get id model of
        Just server ->
            let
                ( filesystem_, cmd, dispatch ) =
                    Filesystem.update game msg (getFilesystem server)

                server_ =
                    setFilesystem filesystem_ server

                model_ =
                    safeUpdate id server_ model
            in
                ( model_, cmd, dispatch )

        Nothing ->
            ( model, Cmd.none, Dispatch.none )


log :
    Game.Model
    -> ID
    -> Logs.Msg
    -> Model
    -> ( Model, Cmd Game.Msg, Dispatch )
log game id msg model =
    case get id model of
        Just server ->
            let
                ( logs_, cmd, dispatch ) =
                    Logs.update game msg (getLogs server)

                server_ =
                    setLogs logs_ server

                model_ =
                    safeUpdate id server_ model
            in
                ( model_, cmd, dispatch )

        Nothing ->
            ( model, Cmd.none, Dispatch.none )


tunnel :
    Game.Model
    -> ID
    -> Tunnels.Msg
    -> Model
    -> ( Model, Cmd Game.Msg, Dispatch )
tunnel game id msg model =
    case get id model of
        Just server ->
            let
                ( tunnels_, cmd, dispatch ) =
                    Tunnels.update game msg (getTunnels server)

                cmd_ =
                    cmd
                        |> Cmd.map (TunnelsMsg id)
                        |> Cmd.map Game.ServersMsg

                server_ =
                    setTunnels tunnels_ server

                model_ =
                    safeUpdate id server_ model
            in
                ( model_, cmd_, dispatch )

        Nothing ->
            ( model, Cmd.none, Dispatch.none )


process :
    Game.Model
    -> ID
    -> Processes.Msg
    -> Model
    -> ( Model, Cmd Game.Msg, Dispatch )
process game id msg model =
    case get id model of
        Just server ->
            let
                ( processes_, cmd, dispatch ) =
                    Processes.update game msg (getProcesses server)

                server_ =
                    setProcesses processes_ server

                model_ =
                    safeUpdate id server_ model
            in
                ( model_, cmd, dispatch )

        Nothing ->
            ( model, Cmd.none, Dispatch.none )


bootstrap :
    Game.Model
    -> Value
    -> Model
    -> ( Model, Cmd Game.Msg, Dispatch )
bootstrap game json model =
    -- FIXME: this is not looking good
    let
        reducer server ( dict, cmd, dispatch ) =
            let
                server_ =
                    { name = "tmp"
                    , nip = ( "", "" )
                    , nips = [ ( "", "" ) ]
                    , filesystem = Filesystem.initialFilesystem
                    , logs = LogsModel.initialLogs
                    , processes = Processes.initialProcesses
                    , tunnels = Tunnels.initialModel
                    , meta =
                        GatewayMeta <| GatewayMetadata Nothing Nothing
                    , coordinates = 0
                    }

                dictWithServer =
                    insert server.id server_ dict

                ( dict_, cmd2, dispatch2 ) =
                    log game
                        server.id
                        (Logs.BootstrapLogs server.logs)
                        dictWithServer

                cmd_ =
                    Cmd.batch [ cmd, cmd2 ]

                dispatch_ =
                    Dispatch.batch [ dispatch, dispatch2 ]
            in
                ( dict_, cmd_, dispatch_ )
    in
        case Decode.decodeValue (Decode.list Decode.value) json of
            Ok list ->
                list
                    |> List.filterMap
                        (Server.decoder >> Result.toMaybe)
                    |> List.foldl reducer
                        ( model, Cmd.none, Dispatch.none )

            Err _ ->
                ( model, Cmd.none, Dispatch.none )
