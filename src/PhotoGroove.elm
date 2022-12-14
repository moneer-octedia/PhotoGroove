module PhotoGroove exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Browser
import Http
import Json.Decode exposing (Decoder, int, list, string, succeed)
import Json.Decode.Pipeline as Pipe exposing (optional, required)
import Json.Encode as Encode
import Random
import Html.Attributes as Attrs exposing (..)

type Status 
    = Loading
    | Loaded (List Photo) String
    | Errored String

type ThumbnailSize = 
    Small | Medium | Large

type alias Photo =
    { url : String
    , size : Int
    , title : String 
    }

photoDecoder : Decoder Photo
photoDecoder = 
    succeed Photo
        |> Pipe.required "url" string
        |> Pipe.required "size" int
        |> optional "title" string "(untitled)"

type alias Model =
    { status : Status
    , chosenSize : ThumbnailSize
    }

type Msg 
    = ClickedPhoto String
    | ClickedSize ThumbnailSize
    | ClickedSurpriseMe
    | GotRandomPhoto Photo
    | GotPhotos (Result Http.Error (List Photo))


urlPrefix : String
urlPrefix =
    "http://elm-in-action.com/"

view : Model -> Html Msg
view model =
    div [ class "content" ] <|
        case model.status of 
            Loaded photos selectedUrl -> 
                viewLoaded photos selectedUrl model.chosenSize
            Loading -> 
                []
            Errored errorMessage -> 
                [ text ("Error: " ++ errorMessage) ]
            

viewLoaded : List Photo -> String -> ThumbnailSize -> List (Html Msg)
viewLoaded photos selectedUrl chosenSize = 
       [ h1 [] [ text "Photo Groove" ]
        , button
            [ onClick ClickedSurpriseMe ]
            [ text "Surprise Me!" ]
        , div [ class "filters" ]
            [ viewFilter "Hue" 0 
            , viewFilter "Ripple" 0
            , viewFilter "Noise" 0
            ]
        , h3 [] [ text "Thumbnail Size:" ]
        , div [ id "choose-size" ]
            (List.map viewSizeChooser [ Small, Medium, Large ])
        , div [ id "thumbnails", class (sizeToString chosenSize)]
            (List.map (viewThumbnail selectedUrl) photos)
        , img 
            [ class "large"
            , src (urlPrefix ++ "large/" ++ selectedUrl)
            ]
            []
        ]


viewThumbnail : String -> Photo -> Html Msg
viewThumbnail selectedUrl thumb =
    img
        [ src (urlPrefix ++ thumb.url)
        , title (thumb.title ++ " [" ++ String.fromInt thumb.size ++ " KB]")
        , classList [ ( "selected", selectedUrl == thumb.url ) ]
        , onClick (ClickedPhoto thumb.url) 
        ]
        []

viewSizeChooser : ThumbnailSize -> Html Msg
viewSizeChooser size =
    label []
        [ input [ type_ "radio", name "size", onClick (ClickedSize size) ] []
        , text (sizeToString size)
        ]

viewFilter : String -> Int -> Html Msg
viewFilter name magnitude =
    div [ class "filter-slider" ]
        [ label [] [ text name ]
        , rangeSlider
            [ Attrs.max "11"
            , Attrs.property "val" (Encode.int magnitude)
            ]
            []
        , label [] [ text (String.fromInt magnitude) ]
        ]


sizeToString : ThumbnailSize -> String
sizeToString size = 
    case size of
        Small -> "small"
        Medium -> "med"
        Large -> "large"
     

initialModel : Model
initialModel =
    { status = Loading
    , chosenSize = Medium
    }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model = 
    case msg of 
        ClickedPhoto url ->
            ({ model | status = selectUrl url model.status }, Cmd.none)
        ClickedSize size ->
            ({ model | chosenSize = size}, Cmd.none)
        ClickedSurpriseMe ->
            case model.status of 
                Loaded (firstPhoto :: otherPhoto) _ ->
                    Random.uniform firstPhoto otherPhoto 
                        |> Random.generate GotRandomPhoto
                        |> Tuple.pair model
                Loaded [] _ -> 
                    ( model, Cmd.none )
                Loading ->
                    (model, Cmd.none)
                Errored _ ->
                    (model, Cmd.none)
        GotRandomPhoto photo ->
            ( { model | status = selectUrl photo.url model.status}, Cmd.none )
        GotPhotos (Ok photos) ->    
            case photos of
                first :: rest -> 
                    ( { model | status = Loaded photos first.url }
                    , Cmd.none
                    )
                [] -> 
                    ( { model | status = Errored "0 photos found" }, Cmd.none )
        GotPhotos (Err _) ->
            ( { model | status = Errored "Server error!" }, Cmd.none )

initialCmd : Cmd Msg
initialCmd = 
    Http.get
        { url = "http://elm-in-action.com/photos/list.json"
        , expect = Http.expectJson GotPhotos (Json.Decode.list photoDecoder)
        }

selectUrl : String -> Status -> Status
selectUrl url status =
    case status of
        Loaded photos _ ->
            Loaded photos url
        Loading ->
            status
        Errored _ -> 
            status

main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> (initialModel, initialCmd)
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }

rangeSlider : List (Attribute msg) -> List (Html msg) -> Html msg
rangeSlider attributes children = 
    node "range-slider" attributes children