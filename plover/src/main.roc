app "Plover"
    packages {
        cli: "https://github.com/roc-lang/basic-cli/releases/download/0.7.1/Icc3xJoIixF3hCcfXrDwLCu4wQHtNdPyoJkEbkgIElA.tar.br",
    }
    imports [
        cli.Stdout,
        cli.Stdin,
        cli.Stderr,
        cli.Arg,
        cli.Task.{ Task },
        cli.Path,
        cli.File,
        Token,
        Scanner,
        Ast,
        Parser,
    ]
    provides [main] to cli

main : Task {} I32
main =
    parsed =
        "-123 * 45.67"
        |> Scanner.scan
        |> Parser.parseExpression

    when parsed is
        Ok expr ->
            expr |> Ast.toExprStr |> Stdout.line

        Err (ParseError _token message) ->
            Stdout.line message

# main : Task {} I32
# main =
#     args <- Arg.list |> Task.await

#     when args is
#         [_programName] ->
#             runPrompt {}

#         [_programName, fileName] ->
#             runFile fileName

#         _ ->
#             {} <- Stdout.line "Usage: plover [script]" |> Task.await
#             Task.err 64

runPrompt : {} -> Task {} I32
runPrompt = \{} ->
    Task.loop {} \_ ->
        {} <- Stdout.write "> " |> Task.await
        input <- Stdin.line |> Task.await
        when input is
            Input source ->
                source
                |> run
                |> Task.await \_ -> Task.ok (Step {})

            End -> Task.ok (Done {})

runFile : Str -> Task {} I32
runFile = \fileName ->
    fileName
    |> Path.fromStr
    |> File.readUtf8
    |> Task.await run
    |> handleErr

run : Str -> Task {} *
run = \source ->
    source
    |> Scanner.scan
    |> List.map Token.toStr
    |> Str.joinWith "\n"
    |> Stdout.line

handleErr : Task a _ -> Task a I32
handleErr = \task ->
    getOut = \err ->
        when err is
            FileReadErr _ _ ->
                ("Error reading file", 1)

            FileReadUtf8Err _ _ ->
                ("Error reading file, UTF8 encoding issue", 1)

    Task.onErr task \err ->
        (message, code) = getOut err
        {} <- Stderr.line message |> Task.await
        Task.err code
