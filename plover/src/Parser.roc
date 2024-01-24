interface Parser
    exposes [parseExpression]
    imports [
        Token.{ Token },
        Ast.{ Expr },
    ]

ParseState : { tokens : List Token, pos : Nat }
ParseResult a : Result (ParseState, a) [ParseError Token Str]

# Trying to use these type aliases produces the error:
#
# thread '<unnamed>' panicked at 'not yet implemented: TODO (@460-470 `17.IdentId(4)`, Index(36))', crates/compiler/constrain/src/expr.rs:3685:22
# note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
#
# It seems like there's a missing branch in type inference for resolving type
# aliases that contain closures
#
# Parser a : ParseState -> Result (ParseState, a) [ParseError Token Str]
# ContinuedParser a b : (ParseState, a) -> Result (ParseState, b) [ParseError Token Str]

parseExpression : List Token -> Result Expr [ParseError Token Str]
parseExpression = \tokens ->
    (_state, expr) <- { tokens, pos: 0 } |> expression |> Result.try
    Ok expr

expression : ParseState -> ParseResult Expr
expression = \state ->
    equality state

equality : ParseState -> ParseResult Expr
equality = \state ->
    state
    |> comparison
    |> Result.try equalityLoop

equalityLoop : (ParseState, Expr) -> ParseResult Expr
equalityLoop = \(state, left) ->
    if matchAny state [BangEqual, EqualEqual] then
        (state1, operator) <- takeToken state |> Result.try
        (state2, right) <- comparison state1 |> Result.try
        expr = Binary { left, operator, right }
        equalityLoop (state2, expr)
    else
        Ok (state, left)

comparison : ParseState -> ParseResult Expr
comparison = \state ->
    state
    |> term
    |> Result.try comparisonLoop

comparisonLoop : (ParseState, Expr) -> ParseResult Expr
comparisonLoop = \(state, left) ->
    if matchAny state [Greater, GreaterEqual, Less, LessEqual] then
        (state1, operator) <- takeToken state |> Result.try
        (state2, right) <- term state1 |> Result.try
        expr = Binary { left, operator, right }
        comparisonLoop (state2, expr)
    else
        Ok (state, left)

term : ParseState -> ParseResult Expr
term = \state ->
    state
    |> factor
    |> Result.try termLoop

termLoop : (ParseState, Expr) -> ParseResult Expr
termLoop = \(state, left) ->
    if matchAny state [Minus, Plus] then
        (state1, operator) <- takeToken state |> Result.try
        (state2, right) <- factor state1 |> Result.try
        expr = Binary { left, operator, right }
        termLoop (state2, expr)
    else
        Ok (state, left)

factor : ParseState -> ParseResult Expr
factor = \state ->
    state
    |> unary
    |> Result.try factorLoop

factorLoop : (ParseState, Expr) -> ParseResult Expr
factorLoop = \(state, left) ->
    if matchAny state [Slash, Star] then
        (state1, operator) <- takeToken state |> Result.try
        (state2, right) <- unary state1 |> Result.try
        expr = Binary { left, operator, right }
        factorLoop (state2, expr)
    else
        Ok (state, left)

unary : ParseState -> ParseResult Expr
unary = \state ->
    if matchAny state [Bang, Minus] then
        (state1, operator) <- takeToken state |> Result.try
        (state2, expr) <- unary state1 |> Result.try
        Ok (state2, Unary { operator, expr })
    else
        primary state

primary : ParseState -> ParseResult Expr
primary = \state ->
    (state1, token) <- takeToken state |> Result.try

    when token.kind is
        False -> Ok (state1, Literal { value: Boolean Bool.false })
        True -> Ok (state1, Literal { value: Boolean Bool.true })
        Nil -> Ok (state1, Literal { value: Nil })
        Number n -> Ok (state1, Literal { value: Number n })
        String s -> Ok (state1, Literal { value: String s })
        LeftParen ->
            crash "fooo"

        # (state2, expr) <- expression state1 |> Result.try
        # if match state2 RightParen then
        #     Ok (advance state2, Grouping { expr })
        # else
        #     Err (error state2 "Expect ')' after expression.")
        _ -> Err (error state "Expected expression")

error : ParseState, Str -> [ParseError Token Str]
error = \state, message ->
    ParseError (peekToken state) message

takeToken : ParseState -> ParseResult Token
takeToken = \state ->
    token = peekToken state
    if token.kind == Eof then
        Ok (state, token)
    else
        Ok (advance state, token)

peekToken : ParseState -> Token
peekToken = \{ tokens, pos } ->
    tokens
    |> List.get pos
    |> Result.withDefault { kind: Eof, lexeme: "", line: 0 }

matchAny : ParseState, List Token.Kind -> Bool
matchAny = \state, candidates ->
    List.any candidates \kind -> match state kind

match : ParseState, Token.Kind -> Bool
match = \state, kind ->
    (peekToken state).kind == kind

advance : ParseState -> ParseState
advance = \state -> { state & pos: state.pos + 1 }
