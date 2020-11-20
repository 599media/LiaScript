module Lia.Markdown.Effect.Script.Types exposing
    ( Script
    , Scripts
    , Stdout(..)
    , count
    , filterMap
    , get
    , isError
    , outputs
    , push
    , replaceInputs
    , scriptChildren
    , set
    , text
    , updateChildren
    )

import Array exposing (Array)
import Lia.Markdown.Effect.Script.Input as Input exposing (Input)
import Lia.Markdown.Effect.Script.Intl as Intl exposing (Intl)
import Lia.Markdown.HTML.Attributes as Attr exposing (Parameters)
import Port.Eval as Eval
import Regex


type alias Scripts =
    Array Script


type Stdout
    = Error String
    | Text String
    | HTML String
    | LIASCRIPT String


isError : Stdout -> Bool
isError stdout =
    case stdout of
        Error _ ->
            True

        _ ->
            False


text : Stdout -> Maybe String
text stdout =
    case stdout of
        Text str ->
            Just str

        _ ->
            Nothing


type alias Script =
    { effect_id : Int
    , script : String
    , updated : Bool -- use this for preventing closing
    , running : Bool
    , update : Bool
    , runOnce : Bool
    , modify : Bool
    , edit : Bool
    , result : Maybe Stdout
    , output : Maybe String
    , inputs : List String
    , counter : Int
    , input : Input
    , intl : Maybe Intl
    }


input : Regex.Regex
input =
    Maybe.withDefault Regex.never <|
        Regex.fromString "@input\\(`([^`]+)`\\)"


push : String -> Int -> Parameters -> String -> Scripts -> Scripts
push lang id params script javascript =
    Array.push
        { effect_id = id
        , script = script
        , updated = False -- use this for preventing closing
        , running = False
        , update = False
        , runOnce = Attr.isSet "run-once" params
        , modify = Attr.isNotSet "modify" params
        , edit = False
        , result =
            params
                |> Attr.get "default"
                |> Maybe.map Text
        , output = Attr.get "output" params
        , inputs =
            script
                |> Regex.find input
                |> List.map .submatches
                |> List.concat
                |> List.filterMap identity
        , counter = 0
        , input = Input.from params
        , intl = Intl.from lang params
        }
        javascript


count : Array Script -> Int
count =
    Array.length >> (+) -1


filterMap : (Script -> Bool) -> (Script -> x) -> Array Script -> List ( Int, x )
filterMap filter map =
    Array.toIndexedList
        >> List.filter (Tuple.second >> filter)
        >> List.map (Tuple.mapSecond map)


outputs : Scripts -> List ( String, String )
outputs =
    Array.toList
        >> List.filterMap
            (\js ->
                case ( js.output, js.result ) of
                    ( Just output, Just (Text result) ) ->
                        Just ( output, result )

                    _ ->
                        Nothing
            )


replaceInputs : Scripts -> List ( Int, String, String ) -> List ( Int, String )
replaceInputs javascript =
    let
        inputs =
            outputs javascript
    in
    List.map
        (\( id, script, input_ ) ->
            ( id
            , inputs
                |> List.foldl Eval.replace_input script
                |> Eval.replace_0 input_
            )
        )


updateChildren : String -> Array Script -> Array Script
updateChildren output =
    Array.map
        (\js ->
            if js.running && List.member output js.inputs then
                { js | update = True }

            else
                js
        )


scriptChildren : String -> Array Script -> List ( Int, String )
scriptChildren output javascript =
    javascript
        |> Array.toIndexedList
        |> List.filterMap
            (\( i, js ) ->
                if not js.running && List.member output js.inputs then
                    Just ( i, js.script, js.input.value )

                else
                    Nothing
            )
        |> replaceInputs javascript


get : (Script -> x) -> Int -> Array Script -> Maybe x
get fn id =
    Array.get id >> Maybe.map fn


set : Int -> (Script -> Script) -> Array Script -> Array Script
set idx fn javascript =
    case Array.get idx javascript of
        Just js ->
            Array.set idx (fn js) javascript

        _ ->
            javascript
