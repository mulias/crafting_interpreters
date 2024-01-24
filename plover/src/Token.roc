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

toStr = \token ->
    token
    |> Inspect.toInspector
    |> Inspect.apply (Inspect.init {})
    |> Inspect.toStr
