interface Scanner
    exposes [scan]
    imports [Token.{ Token }]

Scanner : {
    source : List U8,
    tokens : List Token,
    startPos : Nat,
    currentPos : Nat,
    line : Nat,
}

scan = \source ->
    {
        source: Str.toUtf8 source,
        tokens: [],
        startPos: 0,
        currentPos: 0,
        line: 1,
    }
    |> loop
    |> .tokens

loop : Scanner -> Scanner
loop = \scanner ->
    if atEnd scanner then
        scanner
    else
        scanner |> step |> loop

step = \scanner ->
    nextChar = peek scanner
    nextScanner = advance scanner

    when nextChar is
        0 -> nextScanner
        '(' -> nextScanner |> addToken LeftParen
        ')' -> nextScanner |> addToken RightParen
        '{' -> nextScanner |> addToken LeftBrace
        '}' -> nextScanner |> addToken RightBrace
        ',' -> nextScanner |> addToken Comma
        '.' -> nextScanner |> addToken Dot
        '-' -> nextScanner |> addToken Minus
        '+' -> nextScanner |> addToken Plus
        ';' -> nextScanner |> addToken Semicolon
        '*' -> nextScanner |> addToken Star
        '/' -> nextScanner |> addToken Slash
        '!' ->
            if peek nextScanner == '=' then
                nextScanner |> advance |> addToken BangEqual
            else
                nextScanner |> addToken Bang

        '=' ->
            if peek nextScanner == '=' then
                nextScanner |> advance |> addToken EqualEqual
            else
                nextScanner |> addToken Equal

        '<' ->
            if peek nextScanner == '=' then
                nextScanner |> advance |> addToken LessEqual
            else
                nextScanner |> addToken Less

        '>' ->
            if peek nextScanner == '=' then
                nextScanner |> advance |> addToken GreaterEqual
            else
                nextScanner |> addToken Greater

        '\n' ->
            nextScanner |> commit |> nextLine

        w if isWhitespace w ->
            nextScanner |> commit

        '"' ->
            nextScanner |> commit |> scanString

        d if isDigit d ->
            nextScanner |> scanNumber

        a if isAlpha a ->
            nextScanner |> scanIdentifier

        c ->
            nextScanner |> addToken (Err (UnexpectedChar c))

scanString = \scanner ->
    scannerWithString = scanner |> advanceWhile \c -> c != '"'

    if atEnd scannerWithString then
        token = makeToken scannerWithString \_ -> Err (UnexpectedEnd "Unterminated string")
        scannerWithString |> appendToken token |> commit
    else
        token = makeToken scannerWithString \s -> String s
        scannerWithString |> appendToken token |> advance |> commit

scanNumber = \scanner ->
    scannerWithInteger = scanner |> advanceWhile isDigit

    scannerWithNumber =
        if peek scannerWithInteger == '.' then
            scannerWithInteger
            |> advance
            |> advanceWhile isDigit
        else
            scannerWithInteger

    token = makeToken scannerWithNumber \s ->
        when Str.toDec s is
            Ok n -> Number n
            Err _ -> Err (InvalidNumStr s)

    scannerWithNumber |> appendToken token |> commit

scanIdentifier = \scanner ->
    scannerWithIdentifier = scanner |> advanceWhile \c -> isAlpha c || isDigit c

    token = makeToken scannerWithIdentifier \lexeme ->
        when lexeme is
            "and" -> And
            "class" -> Class
            "else" -> Else
            "false" -> False
            "for" -> For
            "fun" -> Fun
            "if" -> If
            "nil" -> Or
            "print" -> Print
            "return" -> Return
            "super" -> Super
            "this" -> This
            "true" -> True
            "var" -> Var
            "while" -> While
            ident -> Identifier ident

    scannerWithIdentifier |> appendToken token |> commit

addToken = \scanner, kind ->
    token = makeToken scanner \_ -> kind
    scanner |> appendToken token |> commit

makeToken = \scanner, kindBuilder ->
    when tokenText scanner is
        Ok lexeme -> { kind: kindBuilder lexeme, lexeme, line: scanner.line }
        Err _ -> { kind: Err (BadInput (tokenChars scanner)), lexeme: "", line: scanner.line }

tokenChars = \{ source, startPos, currentPos } ->
    List.sublist source { start: startPos, len: currentPos - startPos }

tokenText = \{ source, startPos, currentPos } ->
    Str.fromUtf8Range source { start: startPos, count: currentPos - startPos }

peek : Scanner -> U8
peek = \{ source, currentPos } ->
    source |> List.get currentPos |> Result.withDefault 0

atEnd = \scanner -> peek scanner == 0

advance : Scanner -> Scanner
advance = \scanner ->
    { scanner & currentPos: scanner.currentPos + 1 }

advanceWhile : Scanner, (U8 -> Bool) -> Scanner
advanceWhile = \scanner, test ->
    if test (peek scanner) && !(atEnd scanner) then
        scanner |> advance |> advanceWhile test
    else
        scanner

nextLine = \scanner -> { scanner & line: scanner.line + 1 }

commit = \scanner -> { scanner & startPos: scanner.currentPos }

appendToken = \scanner, token -> { scanner & tokens: List.append scanner.tokens token }

isAlpha = \c -> ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z') || c == '_'

isDigit = \c -> '0' <= c && c <= '9'

isWhitespace = \c -> c == ' ' || c == '\n' || c == '\t' || c == '\r'
