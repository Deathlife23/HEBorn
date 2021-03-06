module Landing.Models exposing (Model, initialModel)

import Landing.Login.Models as Login
import Landing.SignUp.Models as SignUp


type alias Model =
    { login : Login.Model
    , signUp : SignUp.Model
    }


initialModel : Model
initialModel =
    { login = Login.initialModel
    , signUp = SignUp.initialModel
    }
