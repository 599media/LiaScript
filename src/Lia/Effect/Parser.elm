module Lia.Effect.Parser exposing (comment, inline, markdown)

import Combine exposing (..)
import Combine.Num exposing (int)
import Dict
import Lia.Markdown.Inline.Stringify exposing (stringify)
import Lia.Markdown.Inline.Types exposing (Annotation, Inline(..), Inlines)
import Lia.Markdown.Types exposing (Markdown(..))
import Lia.PState exposing (PState)


markdown : Parser PState Markdown -> Parser PState ( Int, Int, List Markdown )
markdown blocks =
    (\i j list -> ( i, j, list ))
        <$> (regex "[\\t ]*{{" *> effect_number)
        <*> (optional 99999 (regex "[\t ]*-[\t ]*" *> int) <* regex "}}[\\t ]*\\n")
        <*> (multi blocks <|> single blocks)


single : Parser PState Markdown -> Parser PState (List Markdown)
single blocks =
    List.singleton <$> (regex "[ \\n\\t]*" *> blocks)


multi : Parser PState Markdown -> Parser PState (List Markdown)
multi blocks =
    regex "[\\t ]*[=]{3,}[\\n]+" *> manyTill (blocks <* regex "[ \\n\\t]*") (regex "[\\t ]*[=]{3,}")


inline : Parser PState Inline -> Parser PState (Annotation -> Inline)
inline inlines =
    EInline
        <$> (string "{{" *> effect_number)
        <*> (optional 99999 (regex "[\t ]*-[\t ]*" *> int) <* string "}}")
        <*> (string "{{" *> manyTill inlines (string "}}"))


effect_number : Parser PState Int
effect_number =
    let
        state n =
            modifyState
                (\s ->
                    if n > s.num_effects then
                        { s | num_effects = n }
                    else
                        s
                )
                *> succeed n
    in
    int >>= state


comment : Parser PState Inlines -> Parser PState ( Int, Inlines )
comment paragraph =
    ((\i n p -> ( i, n, p ))
        <$> (regex "[ \\t]*--{{" *> effect_number)
        <*> (maybe (regex "[ \\t]*<!--" *> regex "[A-Za-z ]+" <* regex "-->[ \\t]*")
                <* regex "}}--[ \\t]*[\\n]+"
            )
        <*> paragraph
    )
        >>= add_comment


add_comment : ( Int, Maybe String, Inlines ) -> Parser PState ( Int, Inlines )
add_comment ( idx, temp_narrator, par ) =
    let
        mod s =
            let
                narrator =
                    case ( temp_narrator, s.defines.local ) of
                        ( Just tmp, _ ) ->
                            String.trim tmp

                        ( Nothing, Just local ) ->
                            local.narrator

                        _ ->
                            s.defines.global.narrator
            in
            { s
                | comment_map =
                    case Dict.get idx s.comment_map of
                        Just ( nrt, str ) ->
                            Dict.insert idx ( nrt, str ++ "\\n" ++ stringify par ) s.comment_map

                        _ ->
                            Dict.insert idx ( narrator, stringify par ) s.comment_map
            }
    in
    modifyState mod *> succeed ( idx, par )
