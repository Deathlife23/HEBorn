module Game.Storyline.Update exposing (update)

import Utils.React as React exposing (React)
import Game.Storyline.Config exposing (..)
import Game.Storyline.Models exposing (..)
import Game.Storyline.Messages exposing (..)
import Game.Storyline.Missions.Messages as Missions
import Game.Storyline.Missions.Update as Missions
import Game.Storyline.Emails.Messages as Emails
import Game.Storyline.Emails.Update as Emails


type alias UpdateResponse msg =
    ( Model, React msg )


update : Config msg -> Msg -> Model -> UpdateResponse msg
update config msg model =
    case msg of
        MissionsMsg msg ->
            onMission config msg model

        EmailsMsg msg ->
            onEmail config msg model


onMission : Config msg -> Missions.Msg -> Model -> UpdateResponse msg
onMission config msg model =
    let
        config_ =
            missionsConfig config

        ( missions, react ) =
            Missions.update config_ msg <| getMissions model

        model_ =
            setMissions missions model
    in
        ( model_, react )


onEmail : Config msg -> Emails.Msg -> Model -> UpdateResponse msg
onEmail config msg model =
    let
        config_ =
            emailsConfig config

        ( emails, react ) =
            Emails.update config_ msg <| getEmails model

        model_ =
            setEmails emails model
    in
        ( model_, react )
