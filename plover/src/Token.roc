interface Token exposes [Token, Kind, ErrorReason, toStr] imports []

Token : {
    kind : Kind,
    lexeme : Str,
    line : Nat,
}

Kind : [
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    Comma,
    Dot,
    Minus,
    Plus,
    Semicolon,
    Slash,
    Star,
    Bang,
    BangEqual,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    Identifier Str,
    String Str,
    Number Dec,
    And,
    Class,
    Else,
    False,
    Fun,
    For,
    If,
    Nil,
    Or,
    Print,
    Return,
    Super,
    This,
    True,
    Var,
    While,
    Eof,
    Err ErrorReason,
]

ErrorReason : [
    UnexpectedChar U8,
    BadInput (List U8),
    InvalidNumStr Str,
    UnexpectedEnd Str,
]

# An internal compiler expectation was broken.
# This is definitely a compiler bug.
# Please file an issue here: https://github.com/roc-lang/roc/issues/new/choose
# thread 'main' panicked at 'Undefined Symbol in relocation, (+eae3, Relocation { kind: PltRelative, encoding: Generic, size: +20, target: Symbol(SymbolIndex(+16f)), addend: +fffffffffffffffc, implicit_addend: false }): Ok(Symbol { name: "__modti3", address: +0, size: +0, kind: Unknown, section: Undefined, scope: Unknown, weak: false, flags: Elf { st_info: +10, st_other: +0 } })', crates/linker/src/elf.rs:1486:25
# note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
# toStr = Inspect.toStr

toStr = \{ kind, lexeme } ->
    when kind is
        LeftParen -> "LeftParen"
        RightParen -> "RightParen"
        LeftBrace -> "LeftBrace"
        RightBrace -> "RightBrace"
        Comma -> "Comma"
        Dot -> "Dot"
        Minus -> "Minus"
        Plus -> "Plus"
        Semicolon -> "Semicolon"
        Slash -> "Slash"
        Star -> "Star"
        Bang -> "Bang"
        BangEqual -> "BangEqual"
        Equal -> "Equal"
        EqualEqual -> "EqualEqual"
        Greater -> "Greater"
        GreaterEqual -> "GreaterEqual"
        Less -> "Less"
        LessEqual -> "LessEqual"
        Identifier s -> "Identifier \(s)"
        String s -> "String \(s)"
        # need to use the lexeme here, Num.toStr requires the legacy linker
        Number _n -> "Number \(lexeme)"
        And -> "And"
        Class -> "Class"
        Else -> "Else"
        False -> "False"
        Fun -> "Fun"
        For -> "For"
        If -> "If"
        Nil -> "Nil"
        Or -> "Or"
        Print -> "Print"
        Return -> "Return"
        Super -> "Super"
        This -> "This"
        True -> "True"
        Var -> "Var"
        While -> "While"
        Eof -> "Eof"
        Err (UnexpectedChar char) -> "Err UnexpectedChar \(Num.toStr char)"
        Err (InvalidNumStr str) -> "Err InvalidNumberStr \(str)"
        Err (UnexpectedEnd str) -> "Err Unexpected End \(str)"
        Err (BadInput chars) ->
            str = chars |> List.map Num.toStr |> Str.joinWith " "
            "Err BadInput \(str)"
