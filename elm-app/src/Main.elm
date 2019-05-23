port module Main exposing (main)

{-
   Graphql-elm imports
-}

import Array
import Browser
import Graphql.Document
import Graphql.Http
import Graphql.Operation exposing (RootMutation, RootQuery, RootSubscription)
import Graphql.OptionalArgument as OptionalArgument exposing (OptionalArgument(..))
import Graphql.SelectionSet as SelectionSet exposing (SelectionSet, hardcoded)
import Hasura.Enum.Order_by exposing (Order_by(..))
import Hasura.InputObject
    exposing
        ( Boolean_comparison_exp
        , Integer_comparison_exp
        , Todolist_bool_exp
        , Todolist_insert_input
        , Todolist_set_input
        , Users_set_input
        , buildBoolean_comparison_exp
        , buildInteger_comparison_exp
        , buildTodolist_bool_exp
        , buildTodolist_insert_input
        , buildTodolist_order_by
        , buildTodolist_set_input
        , buildUsers_bool_exp
        , buildUsers_set_input
        )
import Hasura.Mutation as Mutation
    exposing
        ( DeleteTodolistRequiredArguments
        , InsertTodolistRequiredArguments
        , UpdateTodolistOptionalArguments
        , UpdateTodolistRequiredArguments
        , UpdateUsersOptionalArguments
        , UpdateUsersRequiredArguments
        , insert_todolist
        )
import Hasura.Object
import Hasura.Object.Online_users as OnlineUser
import Hasura.Object.Todolist as Todolist
import Hasura.Object.Todolist_mutation_response as TodolistMutation
import Hasura.Object.Users as Users
import Hasura.Object.Users_mutation_response as UsersMutation
import Hasura.Query as Query
import Hasura.Scalar as Timestamptz exposing (Timestamptz(..))
import Hasura.Subscription as Subscription exposing (TodolistOptionalArguments)
import Html exposing (Html, a, button, div, form, h1, i, img, input, label, li, nav, p, span, text, ul)
import Html.Attributes
    exposing
        ( checked
        , class
        , classList
        , disabled
        , for
        , href
        , id
        , placeholder
        , title
        , type_
        , value
        )
import Html.Events exposing (onClick, onInput, onSubmit)
import Html.Keyed as Keyed
import Http
import Iso8601
import Json.Decode exposing (Decoder, field, int, string)
import Json.Encode as Encode
import RemoteData exposing (RemoteData)
import Time



{- -}
---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = subscriptions
        }



{-
   Constants
-}
{-
   Replace it with your graphql url
-}


graphql_url : String
graphql_url =
    "https://todo-mvc-elm-backend1.herokuapp.com/v1alpha1/graphql"


signup_url : String
signup_url =
    "https://guarded-woodland-47581.herokuapp.com/signup"


login_url : String
login_url =
    "https://guarded-woodland-47581.herokuapp.com/login"



---- Ports ----


port createSubscriptionToTasks : ( String, String ) -> Cmd msg


port createSubscriptionToOnlineUsers : ( String, String ) -> Cmd msg


port createSubscriptionToPublicTodos : ( String, String ) -> Cmd msg


port gotTodoListData : (Json.Decode.Value -> msg) -> Sub msg


port creatingSubscriptionToTasks : (Int -> msg) -> Sub msg


port gotRecentPublicTodoItem : (Json.Decode.Value -> msg) -> Sub msg


port gotOnlineUsers : (Json.Decode.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    case String.length model.authData.authToken of
        0 ->
            Sub.none

        _ ->
            Sub.batch
                [ gotTodoListData DataReceived
                , gotRecentPublicTodoItem RecentPublicTodoReceived
                , gotOnlineUsers GotOnlineUsers
                , creatingSubscriptionToTasks DataLoading
                , Time.every 10000 Tick
                ]



---- MODEL ----


type alias UserInfo =
    { id : Int
    , name : String
    }


type alias Task =
    { id : Int
    , user_id : Int
    , is_completed : Bool
    , task : String
    }


type alias Tasks =
    List Task


type alias OnlineUsers =
    List OnlineUser


type alias OnlineUser =
    { id : Maybe Int
    , username : Maybe String
    }


type alias Model =
    { tasks : TaskData
    , visibility : String
    , newTask : String
    , mutateTask : MutateTask
    , userInfo : UserInfo
    , authData : AuthData
    , authForm : AuthForm
    , publicTodoInsert : String
    , publicTodoInfo : PublicTodoData
    , online_users : OnlineUsersData
    }


type alias AuthForm =
    { displayForm : DisplayForm
    , isRequestInProgress : Bool
    , requestError : String
    , loginResponse : LoginResponseParser
    , signupResponse : SignupResponseParser
    }


type alias LoginResponseParser =
    RemoteData Http.Error LoginResponseData


type alias LoginResponseData =
    { token : String }


type alias SignupResponseParser =
    RemoteData Http.Error SignupResponseData


type alias SignupResponseData =
    { id : Int, username : String }


type alias TaskWUser =
    { id : Int
    , user_id : Int
    , is_completed : Bool
    , task : String
    , user : User
    }


type alias User =
    { username : String
    }


type alias TasksWUser =
    List TaskWUser


type alias PublicTodoData =
    { tasks : TasksWUser
    , oldestTodoId : Int
    , newTodoCount : Int
    , currentLastTodoId : Int
    }


type alias AuthData =
    { email : String
    , password : String
    , username : String
    , authToken : String
    }


type alias MutationResponse =
    { affected_rows : Int
    }


type alias MutateTask =
    RemoteData (Graphql.Http.Error (Maybe MutationResponse)) (Maybe MutationResponse)


type alias PublicDataFetched =
    RemoteData (Graphql.Http.Error TasksWUser) TasksWUser


type alias UpdateTask =
    RemoteData (Graphql.Http.Error (Maybe MutationResponse)) (Maybe MutationResponse)


type alias UpdateLastSeen =
    RemoteData (Graphql.Http.Error (Maybe MutationResponse)) (Maybe MutationResponse)


type alias DeleteTask =
    RemoteData (Graphql.Http.Error (Maybe MutationResponse)) (Maybe MutationResponse)


type alias AllDeleted =
    RemoteData (Graphql.Http.Error (Maybe MutationResponse)) (Maybe MutationResponse)


type alias TaskData =
    RemoteData Json.Decode.Error Tasks


type alias OnlineUsersData =
    RemoteData Json.Decode.Error OnlineUsers


type alias PublicTaskData =
    RemoteData Json.Decode.Error Tasks



{-
   Initialize the state
-}


type DisplayForm
    = Login
    | Signup


iAT : String
iAT =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwibmFtZSI6ImthcnRoaWt2dDI2IiwiaWF0IjoxNTU4NDM4ODI1Ljc1MiwiaHR0cHM6Ly9oYXN1cmEuaW8vand0L2NsYWltcyI6eyJ4LWhhc3VyYS1hbGxvd2VkLXJvbGVzIjpbIm1pbmUiLCJ1c2VyIl0sIngtaGFzdXJhLXVzZXItaWQiOiIxIiwieC1oYXN1cmEtZGVmYXVsdC1yb2xlIjoidXNlciIsIngtaGFzdXJhLXJvbGUiOiJ1c2VyIn19.cMWDnvYKUn9XVDhI1cSb5Arb5ch8XfuCvLPClTk-xbg"


initialize : Model
initialize =
    { tasks = RemoteData.NotAsked
    , online_users = RemoteData.NotAsked
    , visibility = "All"
    , newTask = ""
    , mutateTask = RemoteData.NotAsked
    , userInfo = UserInfo 1 "Karthik"
    , authData = AuthData "" "" "" iAT
    , authForm = AuthForm Login False "" RemoteData.NotAsked RemoteData.NotAsked
    , publicTodoInsert = ""
    , publicTodoInfo = PublicTodoData [] 0 0 0
    }


getInitialEvent : String -> Cmd Msg
getInitialEvent authToken =
    Cmd.batch
        [ createSubscriptionToTasks ( subscriptionDocument |> Graphql.Document.serializeSubscription, authToken )
        , createSubscriptionToPublicTodos ( publicListSubscription |> Graphql.Document.serializeSubscription, authToken )
        , createSubscriptionToOnlineUsers ( onlineUsersSubscription |> Graphql.Document.serializeSubscription, authToken )
        ]


init : ( Model, Cmd Msg )
init =
    ( initialize
    , getInitialEvent iAT
    )



{-
   Application logic and vars
-}


orderByCreatedAt : Order_by -> OptionalArgument (List Hasura.InputObject.Todolist_order_by)
orderByCreatedAt order =
    Present <| [ buildTodolist_order_by (\args -> { args | created_at = OptionalArgument.Present order }) ]


equalToBoolean : Bool -> OptionalArgument Hasura.InputObject.Boolean_comparison_exp
equalToBoolean isPublic =
    Present <| buildBoolean_comparison_exp (\args -> { args | eq_ = OptionalArgument.Present isPublic })


whereIsPublic : Bool -> OptionalArgument Hasura.InputObject.Todolist_bool_exp
whereIsPublic isPublic =
    Present <| buildTodolist_bool_exp (\args -> { args | is_public = equalToBoolean isPublic })


todoListSubscriptionOptionalArgument : TodolistOptionalArguments -> TodolistOptionalArguments
todoListSubscriptionOptionalArgument optionalArgs =
    { optionalArgs | where_ = whereIsPublic False, order_by = orderByCreatedAt Desc }


subscriptionDocument : SelectionSet Tasks RootSubscription
subscriptionDocument =
    Subscription.todolist todoListSubscriptionOptionalArgument todoListSelection



{-
   Subscribe to active users
-}


onlineUsersSubscription : SelectionSet OnlineUsers RootSubscription
onlineUsersSubscription =
    Subscription.online_users identity onlineUsersSelection


onlineUsersSelection : SelectionSet OnlineUser Hasura.Object.Online_users
onlineUsersSelection =
    SelectionSet.map2 OnlineUser
        OnlineUser.id
        OnlineUser.username



{-
   End of it
-}
{-
   Subscription query to fetch recent todolist
-}


publicTodoListSubscriptionOptionalArgument : TodolistOptionalArguments -> TodolistOptionalArguments
publicTodoListSubscriptionOptionalArgument optionalArgs =
    { optionalArgs | where_ = whereIsPublic True, order_by = orderByCreatedAt Desc }


publicListSubscription : SelectionSet Tasks RootSubscription
publicListSubscription =
    Subscription.todolist publicTodoListSubscriptionOptionalArgument todoListSelection


todoListSelection : SelectionSet Task Hasura.Object.Todolist
todoListSelection =
    SelectionSet.map4 Task
        Todolist.id
        Todolist.user_id
        Todolist.is_completed
        Todolist.task



{-
   Reload public todos definition
-}


publicTodoListQueryLimit : Int -> OptionalArgument Int
publicTodoListQueryLimit limit =
    Present limit


lteLastTodoId : Int -> OptionalArgument Integer_comparison_exp
lteLastTodoId id =
    Present
        (buildInteger_comparison_exp
            (\args ->
                { args
                    | lte_ = Present id
                }
            )
        )


publicTodoListOffsetWhere : Int -> OptionalArgument Todolist_bool_exp
publicTodoListOffsetWhere id =
    Present
        (buildTodolist_bool_exp
            (\args ->
                { args
                    | id = lteLastTodoId id
                    , is_public = equalToBoolean True
                }
            )
        )



{-
   Generates argument as below
   ```
    limit: <value>,
    order_by : [
      {
        created_at: desc
      }
    ],
     where_ : {
       id: {
         _lte: <id>
       },
       is_public: {
         _eq: True
       }
     }
   ```
-}


publicTodoListQueryOptionalArgs : Int -> Int -> TodolistOptionalArguments -> TodolistOptionalArguments
publicTodoListQueryOptionalArgs id limit optionalArgs =
    { optionalArgs | where_ = publicTodoListOffsetWhere id, order_by = orderByCreatedAt Desc, limit = publicTodoListQueryLimit limit }


selectUser : SelectionSet User Hasura.Object.Users
selectUser =
    SelectionSet.map User
        Users.username


todoListSelectionWithUser : SelectionSet TaskWUser Hasura.Object.Todolist
todoListSelectionWithUser =
    SelectionSet.map5 TaskWUser
        Todolist.id
        Todolist.user_id
        Todolist.is_completed
        Todolist.task
        (Todolist.user selectUser)


loadPublicTodoList : Int -> SelectionSet TasksWUser RootQuery
loadPublicTodoList id =
    Query.todolist (publicTodoListQueryOptionalArgs id 7) todoListSelectionWithUser



{-
   End of reload public todos definition
-}


getAuthHeader : String -> (Graphql.Http.Request decodesTo -> Graphql.Http.Request decodesTo)
getAuthHeader token =
    Graphql.Http.withHeader "Authorization" ("Bearer " ++ token)


makeRequest : SelectionSet TasksWUser RootQuery -> String -> Cmd Msg
makeRequest q authToken =
    q
        |> Graphql.Http.queryRequest graphql_url
        |> getAuthHeader authToken
        |> Graphql.Http.send (RemoteData.fromResult >> FetchPublicDataSuccess)



{-
   End of it
-}
{-
   Fetching new todos
-}


gtLastTodoId : Int -> OptionalArgument Integer_comparison_exp
gtLastTodoId id =
    Present
        (buildInteger_comparison_exp
            (\args ->
                { args
                    | gt_ = Present id
                }
            )
        )


newPublicTodosWhere : Int -> OptionalArgument Todolist_bool_exp
newPublicTodosWhere id =
    Present
        (buildTodolist_bool_exp
            (\args ->
                { args
                    | id = gtLastTodoId id
                    , is_public = equalToBoolean True
                }
            )
        )



{-
   Generates argument as below
   ```
    order_by : [
      {
        created_at: desc
      }
    ],
     where_ : {
       id: {
         _gt: <id>
       },
       is_public: {
         _eq: True
       }
     }
   ```
-}


newPublicTodoListQueryOptionalArgs : Int -> TodolistOptionalArguments -> TodolistOptionalArguments
newPublicTodoListQueryOptionalArgs id optionalArgs =
    { optionalArgs | where_ = newPublicTodosWhere id, order_by = orderByCreatedAt Desc }


newTodoQuery : Int -> SelectionSet TasksWUser RootQuery
newTodoQuery id =
    Query.todolist (newPublicTodoListQueryOptionalArgs id) todoListSelectionWithUser


loadNewTodos : SelectionSet TasksWUser RootQuery -> String -> Cmd Msg
loadNewTodos q authToken =
    q
        |> Graphql.Http.queryRequest graphql_url
        |> getAuthHeader authToken
        |> Graphql.Http.send (RemoteData.fromResult >> FetchNewTodoDataSuccess)



{-
   Insert into todolist table
-}


insertTodoObjects : String -> Todolist_insert_input
insertTodoObjects newTask =
    buildTodolist_insert_input
        (\args ->
            { args
                | task = Present newTask
            }
        )


insertArgs : String -> InsertTodolistRequiredArguments
insertArgs newTask =
    InsertTodolistRequiredArguments [ insertTodoObjects newTask ]


getTodoListInsertObject : String -> SelectionSet (Maybe MutationResponse) RootMutation
getTodoListInsertObject newTask =
    insert_todolist identity (insertArgs newTask) mutationResponseSelection


mutationResponseSelection : SelectionSet MutationResponse Hasura.Object.Todolist_mutation_response
mutationResponseSelection =
    SelectionSet.map MutationResponse
        TodolistMutation.affected_rows


makeMutation : SelectionSet (Maybe MutationResponse) RootMutation -> String -> Cmd Msg
makeMutation mutation authToken =
    mutation
        |> Graphql.Http.mutationRequest graphql_url
        |> getAuthHeader authToken
        |> Graphql.Http.send (RemoteData.fromResult >> InsertTask)



{-
   Insert into public todolist
-}


getPublicTodoInsertObj : String -> SelectionSet (Maybe MutationResponse) RootMutation
getPublicTodoInsertObj newPublicTask =
    Mutation.insert_todolist identity (insertPublicTodoArgs newPublicTask) publicTodoMutateResponseSelection


insertPublicTodoObjects : String -> Todolist_insert_input
insertPublicTodoObjects newPublicTask =
    buildTodolist_insert_input
        (\args ->
            { args
                | task = Present newPublicTask
                , is_public = Present True
            }
        )


insertPublicTodoArgs : String -> InsertTodolistRequiredArguments
insertPublicTodoArgs newPublicTask =
    InsertTodolistRequiredArguments [ insertPublicTodoObjects newPublicTask ]


publicTodoMutateResponseSelection : SelectionSet MutationResponse Hasura.Object.Todolist_mutation_response
publicTodoMutateResponseSelection =
    SelectionSet.map MutationResponse
        TodolistMutation.affected_rows


makePublicMutation : SelectionSet (Maybe MutationResponse) RootMutation -> String -> Cmd Msg
makePublicMutation mutation authToken =
    mutation
        |> Graphql.Http.mutationRequest graphql_url
        |> getAuthHeader authToken
        |> Graphql.Http.send (RemoteData.fromResult >> PublicTodoMutation)



{-
   End of it
-}
{-
   Update user last_seen
-}
{-
   End of it
-}


updateUserSetArg : String -> Users_set_input
updateUserSetArg timestamp =
    buildUsers_set_input
        (\args ->
            { args
                | last_seen = Present (Timestamptz timestamp)
            }
        )


updateLastSeenArgs : String -> UpdateUsersOptionalArguments -> UpdateUsersOptionalArguments
updateLastSeenArgs timestamp optionalArgs =
    { optionalArgs
        | set_ = Present (updateUserSetArg timestamp)
    }


updateLastSeenWhere : UpdateUsersRequiredArguments
updateLastSeenWhere =
    UpdateUsersRequiredArguments
        (buildUsers_bool_exp (\args -> args))


selectionUpdateUserLastSeen : SelectionSet MutationResponse Hasura.Object.Users_mutation_response
selectionUpdateUserLastSeen =
    SelectionSet.map MutationResponse
        UsersMutation.affected_rows


updateUserLastSeen : String -> SelectionSet (Maybe MutationResponse) RootMutation
updateUserLastSeen currTime =
    Mutation.update_users (updateLastSeenArgs currTime) updateLastSeenWhere selectionUpdateUserLastSeen


updateLastSeen : String -> SelectionSet (Maybe MutationResponse) RootMutation -> Cmd Msg
updateLastSeen authToken updateQuery =
    updateQuery
        |> Graphql.Http.mutationRequest graphql_url
        |> getAuthHeader authToken
        |> Graphql.Http.send (RemoteData.fromResult >> UpdateLastSeen)



{-
   Marking tasks as completed
-}


updateTaskStatus : Int -> Bool -> SelectionSet (Maybe MutationResponse) RootMutation
updateTaskStatus todoId status =
    Mutation.update_todolist (setTodoListUpdateArgs status) (setTodoListUpdateWhere todoId) mutationResponseSelection


setTodoListSetArg : Bool -> Todolist_set_input
setTodoListSetArg status =
    buildTodolist_set_input
        (\args ->
            { args
                | is_completed = OptionalArgument.Present status
            }
        )


setTodoListUpdateArgs : Bool -> UpdateTodolistOptionalArguments -> UpdateTodolistOptionalArguments
setTodoListUpdateArgs status optionalArgs =
    { optionalArgs
        | set_ = Present (setTodoListSetArg status)
    }


setTodoListValueForId : Int -> Integer_comparison_exp
setTodoListValueForId todoId =
    buildInteger_comparison_exp
        (\args ->
            { args
                | eq_ = Present todoId
            }
        )


setTodoListUpdateWhere : Int -> UpdateTodolistRequiredArguments
setTodoListUpdateWhere todoId =
    UpdateTodolistRequiredArguments
        (buildTodolist_bool_exp
            (\args ->
                { args
                    | id = Present (setTodoListValueForId todoId)
                }
            )
        )


updateTodoList : SelectionSet (Maybe MutationResponse) RootMutation -> String -> Cmd Msg
updateTodoList mutation authToken =
    mutation
        |> Graphql.Http.mutationRequest graphql_url
        |> getAuthHeader authToken
        |> Graphql.Http.send (RemoteData.fromResult >> UpdateTask)



{- -}
{-
   Delete todo list
-}


deleteSingleTask : Int -> SelectionSet (Maybe MutationResponse) RootMutation
deleteSingleTask todoId =
    Mutation.delete_todolist (setTodoListDeleteWhere todoId) mutationResponseSelection


setTodoListDeleteWhere : Int -> DeleteTodolistRequiredArguments
setTodoListDeleteWhere todoId =
    DeleteTodolistRequiredArguments
        (buildTodolist_bool_exp
            (\args ->
                { args
                    | id = Present (setTodoListValueForId todoId)
                }
            )
        )


delResponseSelection : SelectionSet MutationResponse Hasura.Object.Todolist_mutation_response
delResponseSelection =
    SelectionSet.map MutationResponse
        TodolistMutation.affected_rows


deleteSingleTodoItem : SelectionSet (Maybe MutationResponse) RootMutation -> String -> Cmd Msg
deleteSingleTodoItem mutation authToken =
    mutation
        |> Graphql.Http.mutationRequest graphql_url
        |> getAuthHeader authToken
        |> Graphql.Http.send (RemoteData.fromResult >> TaskDeleted)



{-
   End of it
-}
{-
   Delete all completed tasks
-}


deleteAllCompletedTask : Int -> SelectionSet (Maybe MutationResponse) RootMutation
deleteAllCompletedTask _ =
    Mutation.delete_todolist (setTodoListDeleteAllCompletedWhere True) mutationResponseSelection


setTodoListValueForTodoStatus : Bool -> Boolean_comparison_exp
setTodoListValueForTodoStatus status =
    buildBoolean_comparison_exp
        (\args ->
            { args
                | eq_ = Present status
            }
        )


setTodoListDeleteAllCompletedWhere : Bool -> DeleteTodolistRequiredArguments
setTodoListDeleteAllCompletedWhere status =
    DeleteTodolistRequiredArguments
        (buildTodolist_bool_exp
            (\args ->
                { args
                    | is_completed = Present (setTodoListValueForTodoStatus status)
                }
            )
        )


delAllResponseSelection : SelectionSet MutationResponse Hasura.Object.Todolist_mutation_response
delAllResponseSelection =
    SelectionSet.map MutationResponse
        TodolistMutation.affected_rows


deleteAllCompletedItems : SelectionSet (Maybe MutationResponse) RootMutation -> String -> Cmd Msg
deleteAllCompletedItems mutation authToken =
    mutation
        |> Graphql.Http.mutationRequest graphql_url
        |> getAuthHeader authToken
        |> Graphql.Http.send (RemoteData.fromResult >> AllCompletedItemsDeleted)



{-
   End of it
-}
---- UPDATE ----
{-
   All the messages this application will respect
-}


type Msg
    = Tick Time.Posix
    | DataLoading Int
    | DataReceived Json.Decode.Value
    | UpdateNewTask String
    | UpdatePublicNewTask String
    | MarkCompleted Int Bool
    | UpdateVisibility String
    | RunMutateTask
    | RunMutatePublicTask
    | InsertTask MutateTask
    | PublicTodoMutation MutateTask
    | UpdateTask UpdateTask
    | UpdateLastSeen UpdateLastSeen
    | TaskDeleted DeleteTask
    | DelTask Int
    | AllCompletedItemsDeleted AllDeleted
    | DeleteAllCompletedItems Int
    | RecentPublicTodoReceived Json.Decode.Value
    | GotOnlineUsers Json.Decode.Value
    | EnteredEmail String
    | EnteredPassword String
    | EnteredUsername String
    | MakeLoginRequest
    | MakeSignupRequest
    | FetchPublicDataSuccess PublicDataFetched
    | FetchNewTodoDataSuccess PublicDataFetched
    | FetchNewPublicTodos
    | ToggleAuthForm DisplayForm
    | GotLoginResponse LoginResponseParser
    | GotSignupResponse SignupResponseParser
    | ClearAuthToken



{-
   | InsertingTask Int
   | TaskInserted Json.Decode.Value
-}
{-
   Encoder and decoder
-}


loginDataEncoder : AuthData -> Encode.Value
loginDataEncoder authData =
    Encode.object
        [ ( "username", Encode.string authData.username )
        , ( "password", Encode.string authData.password )
        ]


decodeLogin : Decoder LoginResponseData
decodeLogin =
    Json.Decode.map LoginResponseData
        (field "token" string)



{-
   For signup
-}


signupDataEncoder : AuthData -> Encode.Value
signupDataEncoder authData =
    Encode.object
        [ ( "username", Encode.string authData.username )
        , ( "password", Encode.string authData.password )
        , ( "confirmPassword", Encode.string authData.password )
        ]


decodeSignup : Decoder SignupResponseData
decodeSignup =
    Json.Decode.map2 SignupResponseData
        (field "id" int)
        (field "username" string)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick newTime ->
            let
                currentIsoTime =
                    Iso8601.fromTime newTime

                updateQuery =
                    updateUserLastSeen currentIsoTime
            in
            ( model
            , updateLastSeen model.authData.authToken updateQuery
            )

        ClearAuthToken ->
            updateAuthData (\authData -> { authData | authToken = "" }) model Cmd.none

        GotLoginResponse data ->
            case data of
                RemoteData.Success d ->
                    updateAuthData (\authData -> { authData | authToken = d.token }) model (getInitialEvent d.token)

                RemoteData.Failure err ->
                    updateAuthFormData (\authForm -> { authForm | isRequestInProgress = False, requestError = "Unable to authenticate you" }) model Cmd.none

                _ ->
                    ( model, Cmd.none )

        GotSignupResponse data ->
            case data of
                RemoteData.Success d ->
                    updateAuthFormData (\authForm -> { authForm | isRequestInProgress = False, requestError = "", displayForm = Login }) model Cmd.none

                RemoteData.Failure err ->
                    updateAuthFormData (\authForm -> { authForm | isRequestInProgress = False, requestError = "Signup failed!" }) model Cmd.none

                _ ->
                    ( model, Cmd.none )

        MakeLoginRequest ->
            let
                loginRequest =
                    Http.post
                        { url = login_url
                        , body = Http.jsonBody (loginDataEncoder model.authData)
                        , expect = Http.expectJson (RemoteData.fromResult >> GotLoginResponse) decodeLogin
                        }
            in
            updateAuthFormData (\authForm -> { authForm | isRequestInProgress = True }) model loginRequest

        MakeSignupRequest ->
            let
                signupRequest =
                    Http.post
                        { url = signup_url
                        , body = Http.jsonBody (signupDataEncoder model.authData)
                        , expect = Http.expectJson (RemoteData.fromResult >> GotSignupResponse) decodeSignup
                        }
            in
            updateAuthFormData (\authForm -> { authForm | isRequestInProgress = True }) model signupRequest

        ToggleAuthForm displayForm ->
            updateAuthFormData (\authForm -> { authForm | displayForm = displayForm }) model Cmd.none

        DataLoading _ ->
            ( { model | tasks = RemoteData.Loading }, Cmd.none )

        GotOnlineUsers data ->
            let
                remoteData =
                    Json.Decode.decodeValue (onlineUsersSubscription |> Graphql.Document.decoder) data |> RemoteData.fromResult
            in
            ( { model | online_users = remoteData }, Cmd.none )

        DataReceived data ->
            let
                remoteData =
                    Json.Decode.decodeValue (subscriptionDocument |> Graphql.Document.decoder) data |> RemoteData.fromResult
            in
            ( { model | tasks = remoteData }, Cmd.none )

        RecentPublicTodoReceived data ->
            let
                remoteData =
                    Json.Decode.decodeValue (publicListSubscription |> Graphql.Document.decoder) data |> RemoteData.fromResult

                {-
                   _ =
                       Debug.log "remoteData" remoteData
                -}
            in
            case remoteData of
                RemoteData.Success recentData ->
                    case List.length recentData > 0 of
                        True ->
                            case Array.get 0 (Array.fromList recentData) of
                                Just recDat ->
                                    case model.publicTodoInfo.oldestTodoId of
                                        0 ->
                                            let
                                                queryObj =
                                                    loadPublicTodoList recDat.id
                                            in
                                            updatePublicTodoData (\publicTodoInfo -> { publicTodoInfo | currentLastTodoId = recDat.id }) model (makeRequest queryObj model.authData.authToken)

                                        _ ->
                                            let
                                                updatedNewTodoCount =
                                                    model.publicTodoInfo.newTodoCount + 1
                                            in
                                            case model.publicTodoInfo.currentLastTodoId == recDat.id of
                                                True ->
                                                    ( model, Cmd.none )

                                                False ->
                                                    updatePublicTodoData (\publicTodoInfo -> { publicTodoInfo | newTodoCount = updatedNewTodoCount }) model Cmd.none

                                Nothing ->
                                    ( model, Cmd.none )

                        False ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        FetchPublicDataSuccess response ->
            case response of
                RemoteData.Success successData ->
                    case List.length successData of
                        0 ->
                            ( model, Cmd.none )

                        _ ->
                            let
                                oldestTodo =
                                    Array.get 0 (Array.fromList (List.foldl (::) [] successData))
                            in
                            case oldestTodo of
                                Just item ->
                                    updatePublicTodoData (\publicTodoInfo -> { publicTodoInfo | tasks = successData, oldestTodoId = item.id }) model Cmd.none

                                Nothing ->
                                    ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        FetchNewTodoDataSuccess response ->
            case response of
                RemoteData.Success successData ->
                    case List.length successData of
                        0 ->
                            ( model, Cmd.none )

                        _ ->
                            let
                                newestTodo =
                                    Array.get 0 (Array.fromList successData)
                            in
                            case newestTodo of
                                Just item ->
                                    updatePublicTodoData (\publicTodoInfo -> { publicTodoInfo | tasks = List.append successData publicTodoInfo.tasks, currentLastTodoId = item.id, newTodoCount = 0 }) model Cmd.none

                                Nothing ->
                                    ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        UpdateNewTask newTask ->
            ( { model | newTask = newTask }, Cmd.none )

        UpdatePublicNewTask newPublicTask ->
            ( { model | publicTodoInsert = newPublicTask }, Cmd.none )

        UpdateVisibility visibility ->
            ( { model | visibility = visibility }, Cmd.none )

        InsertTask response ->
            ( { model | mutateTask = response, newTask = "" }
            , Cmd.none
            )

        PublicTodoMutation _ ->
            ( model
            , Cmd.none
            )

        UpdateTask _ ->
            ( model
            , Cmd.none
            )

        UpdateLastSeen _ ->
            ( model
            , Cmd.none
            )

        TaskDeleted _ ->
            ( model
            , Cmd.none
            )

        AllCompletedItemsDeleted _ ->
            ( model
            , Cmd.none
            )

        RunMutateTask ->
            let
                mutationObj =
                    getTodoListInsertObject model.newTask
            in
            ( { model | mutateTask = RemoteData.Loading }, makeMutation mutationObj model.authData.authToken )

        RunMutatePublicTask ->
            let
                mutationObj =
                    getPublicTodoInsertObj model.publicTodoInsert
            in
            ( { model | publicTodoInsert = "" }, makePublicMutation mutationObj model.authData.authToken )

        FetchNewPublicTodos ->
            let
                newQuery =
                    newTodoQuery model.publicTodoInfo.currentLastTodoId
            in
            ( model, loadNewTodos newQuery model.authData.authToken )

        MarkCompleted id completed ->
            let
                updateObj =
                    updateTaskStatus id (not completed)
            in
            ( model, updateTodoList updateObj model.authData.authToken )

        DelTask id ->
            let
                deleteObj =
                    deleteSingleTask id
            in
            ( model, deleteSingleTodoItem deleteObj model.authData.authToken )

        DeleteAllCompletedItems id ->
            let
                deleteAllObj =
                    deleteAllCompletedTask id
            in
            ( model, deleteAllCompletedItems deleteAllObj model.authData.authToken )

        EnteredEmail email ->
            updateAuthData (\authData -> { authData | email = email }) model Cmd.none

        EnteredPassword password ->
            updateAuthData (\authData -> { authData | password = password }) model Cmd.none

        EnteredUsername username ->
            updateAuthData (\authData -> { authData | username = username }) model Cmd.none


updateAuthData : (AuthData -> AuthData) -> Model -> Cmd Msg -> ( Model, Cmd Msg )
updateAuthData transform model cmd =
    ( { model | authData = transform model.authData }, cmd )


updateAuthFormData : (AuthForm -> AuthForm) -> Model -> Cmd Msg -> ( Model, Cmd Msg )
updateAuthFormData transform model cmd =
    ( { model | authForm = transform model.authForm }, cmd )


updatePublicTodoData : (PublicTodoData -> PublicTodoData) -> Model -> Cmd Msg -> ( Model, Cmd Msg )
updatePublicTodoData transform model cmd =
    ( { model | publicTodoInfo = transform model.publicTodoInfo }, cmd )



---- VIEW ----


viewListItem : Task -> Html Msg
viewListItem task =
    li []
        [ div [ class "view" ]
            [ div [ class "round" ]
                [ input [ checked task.is_completed, type_ "checkbox", id (String.fromInt task.id), onClick (MarkCompleted task.id task.is_completed) ] []
                , label [ for (String.fromInt task.id) ] []
                ]
            ]
        , div
            [ classList
                [ ( "labelContent", True )
                , ( "completed", task.is_completed )
                ]
            ]
            [ div [] [ text task.task ]
            ]
        , button [ class "closeBtn", onClick (DelTask task.id) ]
            [ text "x"
            ]
        ]


viewKeyedListItem : Task -> ( String, Html Msg )
viewKeyedListItem task =
    ( String.fromInt task.id, viewListItem task )


filterTasks : String -> Task -> Bool
filterTasks visibility task =
    case visibility of
        "Completed" ->
            task.is_completed

        "Active" ->
            not task.is_completed

        _ ->
            True


todoListWrapper : String -> Tasks -> UserInfo -> Html Msg
todoListWrapper visibility tasks userInfo =
    div [ class "wrapper" ]
        [ div [ class "todoListWrapper" ]
            [ Keyed.ul [] <|
                List.map viewKeyedListItem (List.filter (filterTasks visibility) tasks)
            ]
        , footerList tasks visibility userInfo
        ]


renderActionBtn : String -> String -> Html Msg
renderActionBtn classVal value =
    li []
        [ a [ class classVal, onClick (UpdateVisibility value) ]
            [ text value
            ]
        ]


activeClass : String -> String -> String
activeClass currentVisibility visibility =
    if currentVisibility == visibility then
        "selected"

    else
        ""


footerActionBtns : String -> Html Msg
footerActionBtns visibility =
    ul []
        [ renderActionBtn (activeClass "All" visibility) "All"
        , renderActionBtn (activeClass "Active" visibility) "Active"
        , renderActionBtn (activeClass "Completed" visibility) "Completed"
        ]


clearButton : UserInfo -> Html Msg
clearButton userInfo =
    button [ class "clearComp", onClick (DeleteAllCompletedItems userInfo.id) ]
        [ text "Clear completed"
        ]


footerList : Tasks -> String -> UserInfo -> Html Msg
footerList tasks visibility userInfo =
    div [ class "footerList" ]
        [ span []
            [ text
                (String.fromInt
                    (List.length
                        (List.filter (filterTasks visibility) tasks)
                    )
                    ++ " Items"
                )
            ]
        , footerActionBtns visibility
        , clearButton userInfo
        ]


renderTasks : Model -> Html Msg
renderTasks model =
    div [ class "tasks_wrapper" ] <|
        case model.tasks of
            RemoteData.NotAsked ->
                [ text "Not asked" ]

            RemoteData.Success tasks ->
                [ todoListWrapper model.visibility tasks model.userInfo ]

            RemoteData.Loading ->
                [ span [ class "loading_text" ]
                    [ text "Loading tasks ..." ]
                ]

            RemoteData.Failure err ->
                [ text ("Error loading data: " ++ Json.Decode.errorToString err) ]


taskMutation : Model -> Html msg
taskMutation model =
    span [ class "mutation_loader" ] <|
        case model.mutateTask of
            RemoteData.NotAsked ->
                [ text "" ]

            RemoteData.Success tasks ->
                [ text "" ]

            RemoteData.Loading ->
                [ i [ class "fa fa-spinner fa-spin" ] []
                ]

            RemoteData.Failure err ->
                [ text "Error loading data: " ]


personalTodos : Model -> Html Msg
personalTodos model =
    div [ class "col-xs-12 col-md-6 sliderMenu p-30" ]
        [ div [ class "todoWrapper" ]
            [ div [ class "sectionHeader" ]
                [ text "Personal todos"
                ]
            , form [ class "formInput", onSubmit RunMutateTask ]
                [ input [ class "input", placeholder "What needs to be done?", onInput UpdateNewTask, value model.newTask ]
                    []
                , i [ class "inputMarker fa fa-angle-right" ] []
                , taskMutation model
                ]
            , renderTasks model
            ]
        ]



{-
   Public
-}


nothing : Html msg
nothing =
    text ""


loadLatestPublicTodo : Int -> Html Msg
loadLatestPublicTodo count =
    case count of
        0 ->
            nothing

        _ ->
            div [ class "loadMoreSection", onClick FetchNewPublicTodos ]
                [ text ("New tasks have arrived! (" ++ String.fromInt count ++ ")")
                ]


publicTodoListWrapper : PublicTodoData -> Html Msg
publicTodoListWrapper publicTodoInfo =
    div [ class "wrapper" ]
        [ loadLatestPublicTodo publicTodoInfo.newTodoCount
        , div
            [ class "todoListWrapper" ]
            [ Keyed.ul [] <|
                List.map publicViewKeyedListItem publicTodoInfo.tasks
            ]
        ]


publicViewListItem : TaskWUser -> Html Msg
publicViewListItem task =
    li []
        [ div [ class "userInfoPublic", title (String.fromInt task.user_id) ]
            [ text ("@" ++ task.user.username)
            ]
        , div [ class "labelContent" ] [ text task.task ]
        ]


publicViewKeyedListItem : TaskWUser -> ( String, Html Msg )
publicViewKeyedListItem task =
    ( String.fromInt task.id, publicViewListItem task )


publicTodos : Model -> Html Msg
publicTodos model =
    div [ class "col-xs-12 col-md-6 sliderMenu p-30 bg-gray border-right" ]
        [ div [ class "todoWrapper" ]
            [ div [ class "sectionHeader" ]
                [ text "Public feed (realtime)"
                ]
            , form [ class "formInput", onSubmit RunMutatePublicTask ]
                [ input [ class "input", placeholder "What needs to be done?", value model.publicTodoInsert, onInput UpdatePublicNewTask ]
                    []
                , i [ class "inputMarker fa fa-angle-right" ] []
                ]
            , publicTodoListWrapper model.publicTodoInfo
            ]
        ]



{-
   Login
-}


textInput : String -> String -> (String -> Msg) -> Html Msg
textInput val p onChange =
    div [ class "authentication_input" ]
        [ input
            [ class "form-control input-lg"
            , placeholder p
            , type_ "text"
            , value val
            , onInput onChange
            ]
            []
        ]


passwordInput : String -> (String -> Msg) -> Html Msg
passwordInput val onChange =
    div [ class "authentication_input" ]
        [ input
            [ class "form-control input-lg"
            , placeholder "Password"
            , type_ "password"
            , value val
            , onInput onChange
            ]
            []
        ]


authenticationToggler : String -> String -> DisplayForm -> Html Msg
authenticationToggler val ref onToggle =
    a [ class "authentication_toggle", href ref, onClick (ToggleAuthForm onToggle) ]
        [ text val
        ]


actionButton : String -> Bool -> Msg -> Html Msg
actionButton val isRequestInProgress clickHandler =
    button
        [ classList
            [ ( "btn-success btn-lg remove_border ", True )
            , ( "disabled", isRequestInProgress )
            ]
        , disabled isRequestInProgress
        , onClick clickHandler
        , type_ "button"
        ]
        [ text val ]


loginView : AuthData -> Bool -> String -> Html Msg
loginView authData isRequestInProgress reqErr =
    div [ class "container authentication_wrapper" ]
        [ div [ class "row" ]
            [ div [ class "col-md-12 col-xs-12" ]
                [ h1 [ class "c_mb_5 ta_center" ]
                    [ text "Sign in"
                    ]
                , p [ class "c_mb_10 ta_center" ]
                    [ authenticationToggler "Register?" "#register" Signup
                    ]
                , form []
                    [ textInput authData.username "Username" EnteredUsername
                    , passwordInput authData.password EnteredPassword
                    , actionButton "Sign in" isRequestInProgress MakeLoginRequest
                    , div [ class "error_auth_response" ] <|
                        case String.length reqErr of
                            0 ->
                                [ text "" ]

                            _ ->
                                [ text ("Login error:  " ++ reqErr) ]
                    ]
                ]
            ]
        ]


signupView : AuthData -> Bool -> String -> Html Msg
signupView authData isRequestInProgress reqErr =
    div [ class "container authentication_wrapper" ]
        [ div [ class "row" ]
            [ div [ class "col-md-12 col-xs-12" ]
                [ h1 [ class "c_mb_5 ta_center" ]
                    [ text "Sign up"
                    ]
                , p [ class "c_mb_10 ta_center" ]
                    [ authenticationToggler "Login?" "#login" Login
                    ]
                , form []
                    [ textInput authData.username "Username" EnteredUsername
                    , passwordInput authData.password EnteredPassword
                    , actionButton "Sign up" isRequestInProgress MakeSignupRequest
                    , text reqErr
                    ]
                ]
            ]
        ]



{-
   End of it
-}


view : Model -> Html Msg
view model =
    div [ class "content" ] <|
        case String.length model.authData.authToken of
            0 ->
                case model.authForm.displayForm of
                    Login ->
                        [ loginView model.authData model.authForm.isRequestInProgress model.authForm.requestError
                        ]

                    Signup ->
                        [ signupView model.authData model.authForm.isRequestInProgress model.authForm.requestError
                        ]

            _ ->
                [ viewTodoSection model
                ]



{-
   The following commented code is TodoMVC code
-}


topNavBar : Html Msg
topNavBar =
    nav [ class "m-bottom-0 navbar navbar-default" ]
        [ div [ class "container-fluid" ]
            [ div [ class "navHeader navbar-header" ]
                [ span [ class "navBrand navbar-brand " ]
                    [ text "Elm Todo Tutorial App"
                    ]
                , ul [ class "nav navbar-nav navbar-right " ]
                    [ li []
                        [ a []
                            [ button
                                [ class "btn-primary", onClick ClearAuthToken ]
                                [ text "Logout" ]
                            ]
                        ]
                    ]
                ]
            ]
        ]


getOnlineUsersCount : OnlineUsersData -> Int
getOnlineUsersCount onlineUsers =
    case onlineUsers of
        RemoteData.Success data ->
            List.length data

        _ ->
            0


generateOnlineUsersList : OnlineUsersData -> List (Html msg)
generateOnlineUsersList onlineUser =
    case onlineUser of
        RemoteData.Success d ->
            List.map viewOnlineUser d

        _ ->
            [ text "" ]


viewUserName : String -> Html msg
viewUserName str =
    div [ class "userInfo" ]
        [ div [ class "userImg" ]
            [ i [ class "far fa-user" ] [] ]
        , div [ class "userName" ]
            [ text str ]
        ]


viewOnlineUser : OnlineUser -> Html msg
viewOnlineUser onlineUser =
    case onlineUser.username of
        Just username ->
            viewUserName username

        Nothing ->
            text ""


viewTodoSection : Model -> Html Msg
viewTodoSection model =
    div [ class "content" ]
        [ topNavBar
        , div [ class "container-fluid p-left-right-0" ]
            [ div [ class "col-xs-12 col-md-9 p-left-right-0" ]
                [ personalTodos model
                , publicTodos model
                ]
            , div [ class "col-xs-12 col-md-3 p-left-right-0" ]
                [ div [ class "col-xs-12 col-md-12 sliderMenu p-30 bg-gray" ]
                    [ div [ class "onlineUsersWrapper" ]
                        [ div [ class "sliderHeader" ]
                            [ text ((++) "Online Users - " (String.fromInt (getOnlineUsersCount model.online_users)))
                            ]
                        , div [] <|
                            generateOnlineUsersList model.online_users
                        ]
                    ]
                ]
            ]
        ]
