module Lia.Parser exposing (run)

import Combine exposing (..)
import Combine.Char exposing (..)
import Combine.Num
import Lia.Type exposing (..)


comments : Parser s ()
comments =
    skip (many (string "{-" *> manyTill anyChar (string "-}")))


blocks : Parser s Block
blocks =
    lazy <|
        \() ->
            let
                b =
                    choice
                        [ table
                        , code_block
                        , quote_block
                        , horizontal_line

                        --  , list
                        , paragraph
                        ]
            in
            comments *> b <* newlines


html : Parser s Inline
html =
    html_void <|> html_block


html_void : Parser s Inline
html_void =
    lazy <|
        \() ->
            HTML
                <$> choice
                        [ regex "<area[^>]*>"
                        , regex "<base[^>]*>"
                        , regex "<br[^>]*>"
                        , regex "<col[^>]*>"
                        , regex "<embed[^>]*>"
                        , regex "<hr[^>]*>"
                        , regex "<img[^>]*>"
                        , regex "<input[^>]*>"
                        , regex "<keygen[^>]*>"
                        , regex "<link[^>]*>"
                        , regex "<menuitem[^>]*>"
                        , regex "<meta[^>]*>"
                        , regex "<param[^>]*>"
                        , regex "<source[^>]*>"
                        , regex "<track[^>]*>"
                        , regex "<wbr[^>]*>"
                        ]


html_block : Parser s Inline
html_block =
    let
        p tag =
            (\c ->
                (c
                    |> String.fromList
                    |> String.append ("<" ++ tag)
                )
                    ++ "</"
                    ++ tag
                    ++ ">"
            )
                <$> manyTill anyChar (string "</" *> string tag <* string ">")
    in
    HTML <$> (whitespace *> string "<" *> regex "[a-z]+" >>= p)



--<* newlines
-- list : Parser s E
-- list =
--     let
--         p1 =
--             string "* " *> line <* newline
--
--         p2 =
--             string "  " *> line <* newline
--     in
--     EList
--         <$> many1
--                 (p1
--                     |> map (::)
--                     |> andMap (many p2)
--                     |> map List.concat
--                 )


horizontal_line : Parser s Block
horizontal_line =
    HorizontalLine <$ regex "--[\\-]+"


paragraph : Parser s Block
paragraph =
    (\l -> Paragraph <| combine <| List.concat l) <$> many (spaces *> line <* newline)


table : Parser s Block
table =
    let
        ending =
            string "|" <* (spaces <* newline)

        row =
            string "|" *> sepBy1 (string "|") (many1 inlines) <* ending

        format =
            string "|"
                *> sepBy1 (string "|")
                    (choice
                        [ regex ":--[\\-]+:" $> "center"
                        , regex ":--[\\-]+" $> "left"
                        , regex "--[\\-]+:" $> "right"
                        , regex "--[\\-]+" $> "left"
                        ]
                    )
                <* ending

        simple_table =
            Table [] [] <$> many1 row <* newline

        format_table =
            Table <$> row <*> format <*> many row <* newline
    in
    choice [ format_table, simple_table ]


combine : List Inline -> List Inline
combine list =
    case list of
        [] ->
            []

        [ xs ] ->
            [ xs ]

        x1 :: x2 :: xs ->
            case ( x1, x2 ) of
                ( Chars str1, Chars str2 ) ->
                    combine (Chars (str1 ++ str2) :: xs)

                _ ->
                    x1 :: combine (x2 :: xs)


line : Parser s (List Inline)
line =
    (\list -> combine <| List.append list [ Chars "\n" ]) <$> many1 inlines


newline : Parser s ()
newline =
    skip (char '\n' <|> eol)


newlines : Parser s ()
newlines =
    skip (many newline)


spaces : Parser s String
spaces =
    regex "[ \t]*"


inlines : Parser s Inline
inlines =
    lazy <|
        \() ->
            let
                p =
                    choice
                        [ html
                        , code_
                        , reference_
                        , strings_
                        ]
            in
            comments *> p


reference_ : Parser s Inline
reference_ =
    lazy <|
        \() ->
            let
                info =
                    brackets (regex "[^\\]\n]*")

                url =
                    parens (regex "[^\\)\n]*")

                link =
                    Link <$> info <*> url

                image =
                    Image <$> (string "!" *> info) <*> url

                movie =
                    Movie <$> (string "!!" *> info) <*> url
            in
            Ref <$> choice [ movie, image, link ]


arrows_ : Parser s Inline
arrows_ =
    lazy <|
        \() ->
            choice
                [ string "<-->" $> Symbol "⟷"
                , string "<--" $> Symbol "⟵"
                , string "-->" $> Symbol "⟶"
                , string "<<-" $> Symbol "↞"
                , string "->>" $> Symbol "↠"
                , string "<->" $> Symbol "↔"
                , string ">->" $> Symbol "↣"
                , string "<-<" $> Symbol "↢"
                , string "->" $> Symbol "→"
                , string "<-" $> Symbol "←"
                , string "<~" $> Symbol "↜"
                , string "~>" $> Symbol "↝"
                , string "<==>" $> Symbol "⟺"
                , string "==>" $> Symbol "⟹"
                , string "<==" $> Symbol "⟸"
                , string "<=>" $> Symbol "⇔"
                , string "=>" $> Symbol "⇒"
                , string "<=" $> Symbol "⇐"
                ]


smileys_ : Parser s Inline
smileys_ =
    lazy <|
        \() ->
            choice
                [ string ":-)" $> Symbol "🙂"
                , string ";-)" $> Symbol "😉"
                , string ":-D" $> Symbol "😀"
                , string ":-O" $> Symbol "😮"
                , string ":-(" $> Symbol "🙁"
                , string ":-|" $> Symbol "😐"
                , string ":-/" $> Symbol "😕"
                , string ":-P" $> Symbol "😛"
                , string ":-*" $> Symbol "😗"
                , string ":')" $> Symbol "😂"
                , string ":'(" $> Symbol "😢"
                ]


between_ : String -> Parser s e -> Parser s e
between_ str p =
    spaces *> string str *> p <* string str


strings_ : Parser s Inline
strings_ =
    lazy <|
        \() ->
            let
                base =
                    Chars <$> regex "[^#*~_:;`!\\^\\[\\|{\\\\\\n\\-<>=|]+" <?> "base string"

                escape =
                    Chars <$> (spaces *> string "\\" *> regex "[\\^#*_~`{\\\\\\|]") <?> "escape string"

                bold =
                    Bold <$> between_ "*" inlines <?> "bold string"

                italic =
                    Italic <$> between_ "~" inlines <?> "italic string"

                underline =
                    Underline <$> between_ "_" inlines <?> "underline string"

                superscript =
                    Superscript <$> between_ "^" inlines <?> "superscript string"

                characters =
                    Chars <$> regex "[*~_:;\\-<>=]"

                base2 =
                    Chars <$> regex "[^#\\n|]+" <?> "base string"
            in
            choice
                [ base
                , html
                , arrows_
                , smileys_
                , escape
                , bold
                , italic
                , underline
                , superscript
                , characters
                , base2
                ]


code_block : Parser s Block
code_block =
    let
        lang =
            string "```" *> spaces *> regex "([a-z,A-Z,0-9])*" <* spaces <* newline

        block =
            String.fromList <$> manyTill anyChar (string "```")
    in
    CodeBlock <$> lang <*> block


quote_block : Parser s Block
quote_block =
    let
        p =
            regex "^" *> string ">" *> optional [ Chars "" ] line <* newline
    in
    (\q -> Quote <| combine <| List.concat q) <$> many1 p


code_ : Parser s Inline
code_ =
    Code <$> (string "`" *> regex "[^`]+" <* string "`") <?> "inline code"


program : Parser s (List Slide)
program =
    let
        tag =
            String.length <$> (newlines *> regex "#+" <* whitespace)

        title =
            String.trim <$> regex ".+" <* many1 newline

        body =
            many blocks
    in
    comments *> many (Slide <$> tag <*> title <*> body)


run : String -> Result String (List Slide)
run script =
    case Combine.parse program script of
        Ok ( _, _, es ) ->
            Ok es

        Err ( _, stream, ms ) ->
            Err <| formatError ms stream


formatError : List String -> InputStream -> String
formatError ms stream =
    let
        location =
            currentLocation stream

        separator =
            "|> "

        expectationSeparator =
            "\n  * "

        lineNumberOffset =
            floor (logBase 10 (toFloat location.line)) + 1

        separatorOffset =
            String.length separator

        padding =
            location.column + separatorOffset + 2
    in
    "Parse error around line:\n\n"
        ++ toString location.line
        ++ separator
        ++ location.source
        ++ "\n"
        ++ String.padLeft padding ' ' "^"
        ++ "\nI expected one of the following:\n"
        ++ expectationSeparator
        ++ String.join expectationSeparator ms
