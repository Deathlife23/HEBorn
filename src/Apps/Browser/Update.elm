module Apps.Browser.Update exposing (update)

import Dict
import Utils.React as React exposing (React)
import Game.Account.Finances.Models as Finances
import Game.Account.Finances.Shared as Finances
import Game.Servers.Models as Servers
import Game.Servers.Shared exposing (StorageId)
import Game.Servers.Filesystem.Shared as Filesystem
import Game.Web.Types as Web
import Game.Meta.Types.Context exposing (Context(..))
import Game.Meta.Types.Network as Network
import Apps.Reference exposing (..)
import Apps.Browser.Pages.Webserver.Update as Webserver
import Apps.Browser.Pages.Bank.Messages as Bank
import Apps.Browser.Pages.Bank.Update as Bank
import Apps.Browser.Pages.DownloadCenter.Update as DownloadCenter
import Apps.Browser.Messages exposing (..)
import Apps.Browser.Config exposing (..)
import Apps.Browser.Models exposing (..)


type alias UpdateResponse msg =
    ( Model, React msg )


type alias TabUpdateResponse msg =
    ( Tab, React msg )


update : Config msg -> Msg -> Model -> UpdateResponse msg
update config msg model =
    case msg of
        LaunchApp context params ->
            onLaunchApp config context params model

        ChangeTab tabId ->
            ( goTab tabId model, React.none )

        NewTab ->
            ( addTab model, React.none )

        NewTabIn url ->
            onNewTabIn config url model

        DeleteTab tabId ->
            ( deleteTab tabId model, React.none )

        PublicDownload nip entry ->
            update config
                (ActiveTabMsg <| EnterModal <| Just <| ForDownload nip entry)
                model

        ReqDownload source file storage ->
            onReqDownload config source file storage model

        HandlePasswordAcquired event ->
            onEveryTabMsg config (Cracked event.nip event.password) model

        ActiveTabMsg msg ->
            updateSomeTabMsg config model.nowTab msg model

        SomeTabMsg tabId msg ->
            updateSomeTabMsg config tabId msg model

        EveryTabMsg msg ->
            onEveryTabMsg config msg model

        BankLogin request ->
            onBankLogin config request model.me model

        BankTransfer request ->
            onBankTransfer config request model.me model

        BankLogout ->
            onBankLogout config model



-- browser internals


onLaunchApp : Config msg -> Context -> Params -> Model -> UpdateResponse msg
onLaunchApp config context (OpenAtUrl url) model =
    let
        filter id tab =
            tab.addressBar == url

        maybeId =
            model.tabs
                |> Dict.filter filter
                |> Dict.keys
                |> List.head
    in
        case maybeId of
            Just id ->
                ( goTab id model, React.none )

            Nothing ->
                onNewTabIn config url model


onNewTabIn : Config msg -> URL -> Model -> UpdateResponse msg
onNewTabIn config url model =
    let
        createTabModel =
            addTab model

        goTabModel =
            goTab
                createTabModel.lastTab
                createTabModel

        tabId =
            goTabModel.nowTab

        tab =
            getTab tabId goTabModel.tabs

        ( tab_, react ) =
            onGoAddress config url model.me tabId tab

        model_ =
            setNowTab tab_ goTabModel
    in
        ( model_, react )


onReqDownload :
    Config msg
    -> Network.NIP
    -> Filesystem.FileEntry
    -> StorageId
    -> Model
    -> UpdateResponse msg
onReqDownload { onNewPublicDownload } source file storage model =
    file
        |> onNewPublicDownload source storage
        |> React.msg
        |> (,) model


onBankLogin :
    Config msg
    -> Finances.BankLoginRequest
    -> Reference
    -> Model
    -> UpdateResponse msg
onBankLogin { onBankAccountLogin } request { sessionId, windowId, context } model =
    { sessionId = sessionId
    , windowId = windowId
    , context = context
    , tabId = model.nowTab
    }
        |> onBankAccountLogin request
        |> React.msg
        |> (,) model


onBankTransfer :
    Config msg
    -> Finances.BankTransferRequest
    -> Reference
    -> Model
    -> UpdateResponse msg
onBankTransfer { onBankAccountTransfer } request { sessionId, windowId, context } model =
    { sessionId = sessionId
    , windowId = windowId
    , context = context
    , tabId = model.nowTab
    }
        |> onBankAccountTransfer request
        |> React.msg
        |> (,) model


onBankLogout : Config msg -> Model -> UpdateResponse msg
onBankLogout config model =
    -- TODO: Bank Logout Request
    ( model, React.none )



-- tabs


updateSomeTabMsg :
    Config msg
    -> Int
    -> TabMsg
    -> Model
    -> UpdateResponse msg
updateSomeTabMsg config tabId msg model =
    let
        tab =
            getTab tabId model.tabs

        setThisTab tab_ =
            { model | tabs = (setTab tabId tab_ model.tabs) }

        ( model_, react ) =
            processTabMsg config tabId msg tab model
    in
        Tuple.mapFirst setThisTab ( model_, react )


onEveryTabMsg : Config msg -> TabMsg -> Model -> UpdateResponse msg
onEveryTabMsg config msg model =
    model.tabs
        |> Dict.foldl (reduceTabMsg config msg model)
            ( Dict.empty, React.none )
        |> Tuple.mapFirst (\tabs_ -> { model | tabs = tabs_ })


reduceTabMsg :
    Config msg
    -> TabMsg
    -> Model
    -> Int
    -> Tab
    -> ( Tabs, React msg )
    -> ( Tabs, React msg )
reduceTabMsg config msg model tabId tab ( tabs, react0 ) =
    let
        ( tab_, react1 ) =
            processTabMsg config tabId msg tab model

        tabs_ =
            Dict.insert tabId tab tabs

        react =
            React.batch
                config.batchMsg
                [ react0, react1 ]
    in
        ( tabs_, react )


processTabMsg :
    Config msg
    -> Int
    -> TabMsg
    -> Tab
    -> Model
    -> TabUpdateResponse msg
processTabMsg config tabId msg tab model =
    case msg of
        GoPrevious ->
            ( gotoPreviousPage tab, React.none )

        GoNext ->
            ( gotoNextPage tab, React.none )

        UpdateAddress url ->
            ( { tab | addressBar = url }, React.none )

        EnterModal modal ->
            ( { tab | modal = modal }, React.none )

        HandleFetched response ->
            handleFetched response tab

        GoAddress url ->
            onGoAddress config url model.me tabId tab

        AnyMap nip ->
            -- TODO: implementation pending
            ( tab, React.none )

        NewApp params ->
            ( tab
            , React.msg <| config.onNewApp Nothing Nothing params
            )

        SelectEndpoint ->
            ( tab
            , React.msg <| config.onSetContext Endpoint
            )

        HandleBankLogin accountData ->
            handleBankLogin config tabId tab accountData model

        HandleBankLoginError ->
            handleBankError config tabId tab model

        HandleBankTransfer ->
            handleBankTransfer config tabId tab model

        HandleBankTransferError ->
            handleBankTransferError config tabId tab model

        Login nip password ->
            onLogin config nip password model.me tabId tab

        HandleLoginFailed ->
            handleLoginFailed tab

        Crack nip ->
            onCrack config nip tab

        Cracked _ _ ->
            -- TODO: forward success
            ( tab, React.none )

        -- site msgs
        _ ->
            onPageMsg config msg tab


handleFetched : Web.Response -> Tab -> TabUpdateResponse msg
handleFetched response tab =
    let
        ( url, pageModel ) =
            case response of
                Web.PageLoaded site ->
                    ( site.url, initialPage site )

                Web.PageNotFound url ->
                    ( url, NotFoundModel { url = url } )

                Web.ConnectionError url ->
                    -- TODO: Change to some "failed" page
                    ( url, BlankModel )

        isLoadingThisRequest =
            (isLoading <| getPage tab)
                && (getURL tab == url)
    in
        if (isLoadingThisRequest) then
            ( gotoPage url pageModel tab, React.none )
        else
            ( tab, React.none )


handleLoginFailed : Tab -> TabUpdateResponse msg
handleLoginFailed tab =
    { tab
        | page =
            case tab.page of
                WebserverModel model ->
                    { model | loginFailed = True }
                        |> WebserverModel

                DownloadCenterModel model ->
                    { model | loginFailed = True }
                        |> DownloadCenterModel

                _ ->
                    tab.page
        , modal = Just ImpossibleToLogin
    }
        |> flip (,) React.none


onGoAddress :
    Config msg
    -> String
    -> Reference
    -> Int
    -> Tab
    -> TabUpdateResponse msg
onGoAddress config url { sessionId, windowId, context } tabId tab =
    let
        networkId =
            config.activeServer
                |> Servers.getActiveNIP
                |> Network.getId

        requester =
            { sessionId = sessionId
            , windowId = windowId
            , context = context
            , tabId = tabId
            }

        react =
            React.msg <| config.onFetchUrl networkId url requester

        tab_ =
            gotoPage url (LoadingModel url) tab
    in
        ( tab_, react )


onLogin :
    Config msg
    -> Network.NIP
    -> String
    -> Reference
    -> Int
    -> Tab
    -> TabUpdateResponse msg
onLogin config remoteNip password { sessionId, windowId, context } tabId tab =
    { sessionId = sessionId
    , windowId = windowId
    , context = context
    , tabId = tabId
    }
        |> config.onWebLogin
            (Servers.getActiveNIP config.activeGateway)
            (Network.getIp remoteNip)
            password
        |> React.msg
        |> (,) tab


onCrack : Config msg -> Network.NIP -> Tab -> TabUpdateResponse msg
onCrack { onNewBruteforceProcess } nip tab =
    nip
        |> Network.getIp
        |> onNewBruteforceProcess
        |> React.msg
        |> (,) tab


onPageMsg : Config msg -> TabMsg -> Tab -> TabUpdateResponse msg
onPageMsg config msg tab =
    let
        ( page_, react ) =
            updatePage config msg tab.page

        tab_ =
            { tab | page = page_ }
    in
        ( tab_, react )


updatePage :
    Config msg
    -> TabMsg
    -> Page
    -> ( Page, React msg )
updatePage config msg tab =
    case ( tab, msg ) of
        ( WebserverModel page, WebserverMsg msg ) ->
            let
                ( tab_, react ) =
                    Webserver.update (webserverConfig config) msg page
            in
                ( WebserverModel tab_, react )

        ( BankModel page, BankMsg msg ) ->
            let
                ( tab_, react ) =
                    Bank.update (bankConfig config) msg page
            in
                ( BankModel tab_, react )

        ( DownloadCenterModel page, DownloadCenterMsg msg ) ->
            let
                ( tab_, react ) =
                    DownloadCenter.update (downloadCenterConfig config) msg page
            in
                ( DownloadCenterModel tab_, react )

        _ ->
            ( tab, React.none )


handleBankLogin :
    Config msg
    -> Int
    -> Tab
    -> Finances.BankAccountData
    -> Model
    -> TabUpdateResponse msg
handleBankLogin config tabId tab accountData model =
    let
        page =
            (getTab tabId model.tabs).page

        ( pageModel, _ ) =
            updatePage config (BankMsg <| Bank.HandleLogin accountData) page
    in
        ( { tab | page = pageModel }, React.none )


handleBankError : Config msg -> Int -> Tab -> Model -> TabUpdateResponse msg
handleBankError config tabId tab model =
    let
        page =
            (getTab tabId model.tabs).page

        ( pageModel, _ ) =
            updatePage config (BankMsg Bank.HandleLoginError) page
    in
        ( { tab | page = pageModel }, React.none )


handleBankTransfer : Config msg -> Int -> Tab -> Model -> TabUpdateResponse msg
handleBankTransfer config tabId tab model =
    let
        page =
            (getTab tabId model.tabs).page

        ( pageModel, _ ) =
            updatePage config (BankMsg Bank.HandleTransfer) page
    in
        ( { tab | page = pageModel }, React.none )


handleBankTransferError : Config msg -> Int -> Tab -> Model -> TabUpdateResponse msg
handleBankTransferError config tabId tab model =
    let
        page =
            (getTab tabId model.tabs).page

        ( pageModel, _ ) =
            updatePage config (BankMsg Bank.HandleTransferError) page
    in
        ( { tab | page = pageModel }, React.none )
