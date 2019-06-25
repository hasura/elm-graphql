port module Main exposing (main)

{-
   Graphql-elm imports
-}

import Array
import Browser
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
import Html.Events exposing (onInput)
import Html.Keyed as Keyed
import Http



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


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



---- MODEL ----


type alias UserInfo =
    { id : Int
    , name : String
    }


type alias Todo =
    { id : Int
    , user_id : String
    , is_completed : Bool
    , title : String
    }


type alias Todos =
    List Todo


type alias OnlineUsers =
    List OnlineUser


type alias OnlineUser =
    { id : String
    , user : User
    }


type alias PrivateTodo =
    { todos : Todos
    , visibility : String
    , newTodo : String
    }


type alias TodoWUser =
    { id : Int
    , user_id : String
    , is_completed : Bool
    , title : String
    , user : User
    }


type alias User =
    { name : String
    }


type alias TodosWUser =
    List TodoWUser


type alias PublicTodoData =
    { todos : TodosWUser
    , oldestTodoId : Int
    , newTodoCount : Int
    , currentLastTodoId : Int
    , oldTodosAvailable : Bool
    }


type Operation
    = NotYetInitiated
    | OnGoing
    | OperationFailed String


type alias Model =
    { privateData : PrivateTodo
    , publicTodoInsert : String
    , publicTodoInfo : PublicTodoData
    , online_users : OnlineUsers
    }



{-
   Initial seed data
-}


seedIds : List Int
seedIds =
    [ 1, 2, 3, 4, 5, 6 ]


todoPrivatePlaceholder : String
todoPrivatePlaceholder =
    "Private Todo"


todoPublicPlaceholder : String
todoPublicPlaceholder =
    "Public Todo"


generateTodo : String -> Int -> Todo
generateTodo placeholder id =
    Todo id ("User" ++ String.fromInt id) False (placeholder ++ "_" ++ String.fromInt id)


privateTodos : Todos
privateTodos =
    List.map (generateTodo todoPrivatePlaceholder) seedIds


generateUser : Int -> User
generateUser id =
    User ("User_" ++ String.fromInt id)


generatePublicTodo : String -> Int -> TodoWUser
generatePublicTodo placeholder id =
    TodoWUser id ("User" ++ String.fromInt id) False (placeholder ++ "_" ++ String.fromInt id) (generateUser id)


getPublicTodos : TodosWUser
getPublicTodos =
    List.map (generatePublicTodo todoPublicPlaceholder) seedIds


generateOnlineUser : Int -> OnlineUser
generateOnlineUser id =
    OnlineUser (String.fromInt id) (generateUser id)


getOnlineUsers : OnlineUsers
getOnlineUsers =
    List.map generateOnlineUser seedIds


initializePrivateTodo : PrivateTodo
initializePrivateTodo =
    { todos = privateTodos
    , visibility = "All"
    , newTodo = ""
    }


initialize : Model
initialize =
    { privateData = initializePrivateTodo
    , online_users = getOnlineUsers
    , publicTodoInsert = ""
    , publicTodoInfo = PublicTodoData getPublicTodos 0 0 0 False
    }


init : ( Model, Cmd Msg )
init =
    ( initialize
    , Cmd.none
    )



---- UPDATE ----


type alias Msg =
    ()


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )



---- VIEW ----


viewListItem : Todo -> Html Msg
viewListItem todo =
    li []
        [ div [ class "view" ]
            [ div [ class "round" ]
                [ input [ checked todo.is_completed, type_ "checkbox", id (String.fromInt todo.id) ] []
                , label [ for (String.fromInt todo.id) ] []
                ]
            ]
        , div
            [ classList
                [ ( "labelContent", True )
                , ( "completed", todo.is_completed )
                ]
            ]
            [ div [] [ text todo.title ]
            ]
        , button [ class "closeBtn" ]
            [ text "x"
            ]
        ]


viewKeyedListItem : Todo -> ( String, Html Msg )
viewKeyedListItem todo =
    ( String.fromInt todo.id, viewListItem todo )


filterTodos : String -> Todo -> Bool
filterTodos visibility todo =
    case visibility of
        "Completed" ->
            todo.is_completed

        "Active" ->
            not todo.is_completed

        _ ->
            True


todoListWrapper : String -> Todos -> Html Msg
todoListWrapper visibility todos =
    div [ class "wrapper" ]
        [ div [ class "todoListWrapper" ]
            [ Keyed.ul [] <|
                List.map viewKeyedListItem (List.filter (filterTodos visibility) todos)
            ]
        , footerList todos visibility
        ]


renderActionBtn : String -> String -> Html Msg
renderActionBtn classVal value =
    li []
        [ a [ class classVal ]
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


clearButton : Html Msg
clearButton =
    button [ class "clearComp" ]
        [ text "Clear completed"
        ]


footerList : Todos -> String -> Html Msg
footerList todos visibility =
    div [ class "footerList" ]
        [ span []
            [ text
                (String.fromInt
                    (List.length
                        (List.filter (filterTodos visibility) todos)
                    )
                    ++ " Items"
                )
            ]
        , footerActionBtns visibility
        , clearButton
        ]


renderTodos : PrivateTodo -> Html Msg
renderTodos privateData =
    div [ class "tasks_wrapper" ]
        [ todoListWrapper privateData.visibility privateData.todos ]


personalTodos : PrivateTodo -> Html Msg
personalTodos privateData =
    div [ class "col-xs-12 col-md-6 sliderMenu p-30" ]
        [ div [ class "todoWrapper" ]
            [ div [ class "sectionHeader" ]
                [ text "Personal todos"
                ]
            , form [ class "formInput" ]
                [ input [ class "input", placeholder "What needs to be done?" ]
                    []
                , i [ class "inputMarker fa fa-angle-right" ] []
                ]
            , renderTodos privateData
            ]
        ]



{-
   Public todo render functions
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
            div [ class "loadMoreSection" ]
                [ text ("New tasks have arrived! (" ++ String.fromInt count ++ ")")
                ]


loadOldPublicTodos : Bool -> Html Msg
loadOldPublicTodos oldTodosAvailable =
    case oldTodosAvailable of
        True ->
            div [ class "loadMoreSection" ]
                [ text "Load older tasks"
                ]

        False ->
            div [ class "loadMoreSection" ]
                [ text "No more public tasks!"
                ]


publicTodoListWrapper : PublicTodoData -> Html Msg
publicTodoListWrapper publicTodoInfo =
    div [ class "wrapper" ]
        [ loadLatestPublicTodo publicTodoInfo.newTodoCount
        , div
            [ class "todoListWrapper" ]
            [ Keyed.ul [] <|
                List.map publicViewKeyedListItem publicTodoInfo.todos
            ]
        , loadOldPublicTodos publicTodoInfo.oldTodosAvailable
        ]


publicViewListItem : TodoWUser -> Html Msg
publicViewListItem todo =
    li []
        [ div [ class "userInfoPublic", title todo.user_id ]
            [ text ("@" ++ todo.user.name)
            ]
        , div [ class "labelContent" ] [ text todo.title ]
        ]


publicViewKeyedListItem : TodoWUser -> ( String, Html Msg )
publicViewKeyedListItem todo =
    ( String.fromInt todo.id, publicViewListItem todo )


publicTodos : Model -> Html Msg
publicTodos model =
    div [ class "col-xs-12 col-md-6 sliderMenu p-30 bg-gray border-right" ]
        [ div [ class "todoWrapper" ]
            [ div [ class "sectionHeader" ]
                [ text "Public feed (realtime)"
                ]
            , form [ class "formInput" ]
                [ input [ class "input", placeholder "What needs to be done?", value model.publicTodoInsert ]
                    []
                , i [ class "inputMarker fa fa-angle-right" ] []
                ]
            , publicTodoListWrapper model.publicTodoInfo
            ]
        ]



{-
   Main view function
-}


view : Model -> Html Msg
view model =
    div [ class "content" ]
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
                                [ class "btn btn-primary" ]
                                [ text "Log Out" ]
                            ]
                        ]
                    ]
                ]
            ]
        ]


getOnlineUsersCount : OnlineUsers -> Int
getOnlineUsersCount onlineUsers =
    List.length onlineUsers


generateOnlineUsersList : OnlineUsers -> List (Html msg)
generateOnlineUsersList onlineUser =
    List.map viewOnlineUser onlineUser


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
    viewUserName onlineUser.user.name


viewTodoSection : Model -> Html Msg
viewTodoSection model =
    div [ class "content" ]
        [ topNavBar
        , div [ class "container-fluid p-left-right-0" ]
            [ div [ class "col-xs-12 col-md-9 p-left-right-0" ]
                [ personalTodos model.privateData
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
