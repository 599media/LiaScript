module Lia.Markdown.Inline.Parser.Symbol exposing (arrows, smileys)

import Combine exposing (Parser, andMap, choice, map, onsuccess, string)
import Lia.Markdown.Inline.Types exposing (Annotation, Inline(..))
<<<<<<< HEAD
<<<<<<< HEAD
import Lia.Parser.State exposing (State)
=======
import Lia.Parser.State exposing (State, getLine)
>>>>>>> new allert version
=======
import Lia.Parser.State exposing (State)
>>>>>>> simplified jumping via a Goto type in inlines


arrows : Parser State (Annotation -> Inline)
arrows =
    choice
        [ string "<-->" |> onsuccess "⟷"
        , string "<--" |> onsuccess "⟵"
        , string "-->" |> onsuccess "⟶"
        , string "<<-" |> onsuccess "↞"
        , string "->>" |> onsuccess "↠"
        , string "<->" |> onsuccess "↔"
        , string ">->" |> onsuccess "↣"
        , string "<-<" |> onsuccess "↢"
        , string "->" |> onsuccess "→"
        , string "<-" |> onsuccess "←"
        , string "<~" |> onsuccess "↜"
        , string "~>" |> onsuccess "↝"
        , string "<==>" |> onsuccess "⟺"
        , string "==>" |> onsuccess "⟹"
        , string "<==" |> onsuccess "⟸"
        , string "<=>" |> onsuccess "⇔"
        , string "=>" |> onsuccess "⇒"
        , string "<=" |> onsuccess "⇐"
        ]
        |> map Symbol


smileys : Parser State (Annotation -> Inline)
smileys =
    choice
        [ string ":-)" |> onsuccess "🙂"
        , string ";-)" |> onsuccess "😉"
        , string ":-D" |> onsuccess "😀"
        , string ":-O" |> onsuccess "😮"
        , string ":-(" |> onsuccess "🙁"
        , string ":-|" |> onsuccess "😐"
        , string ":-/" |> onsuccess "😕"
        , string ":-\\" |> onsuccess "😕"
        , string ":-P" |> onsuccess "😛"
        , string ":-p" |> onsuccess "😛"
        , string ";-P" |> onsuccess "😜"
        , string ";-p" |> onsuccess "😜"
        , string ":-*" |> onsuccess "😗"
        , string ";-*" |> onsuccess "😘"
        , string ":')" |> onsuccess "😂"
        , string ":'(" |> onsuccess "😢"
        , string ":'[" |> onsuccess "😭"
        , string ":-[" |> onsuccess "😠"
        , string ":-#" |> onsuccess "😷"
        , string ":-X" |> onsuccess "😷"
        , string ":-§" |> onsuccess "😖"
        ]
        |> map Symbol
