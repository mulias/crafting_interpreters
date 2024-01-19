interface Ast exposes [Value, Expr, Stmt, toValueStr, toExprStr, toStmtStr] imports [Token.{ Token }]

Value : [String Str, Number Dec, Boolean Bool, Nil]

Expr : [
    Assign { name : Token, value : Expr },
    Binary { left : Expr, operator : Token, right : Expr },
    Call { callee : Expr, paren : Token, arguments : List Expr },
    Grouping { expr : Expr },
    Literal { value : Value },
    Logical { left : Expr, operator : Token, right : Expr },
    Unary { operator : Token, expr : Expr },
    Variable { name : Token },
]

Stmt : [
    Block { stmts : List Stmt },
    Expr { expr : Expr },
    Function { name : Token, params : List Token, body : List Stmt },
    If { condition : Expr, thenBranch : Stmt, elseBranch : [Else Stmt, ImplicitNil] },
    Print { expr : Expr },
    Return { keyword : Token, value : [Value Expr, ImplicitNil] },
    Var { name : Token, initializer : [Value Expr, ImplicitNil] },
    # Don't use a record, this avoids https://github.com/roc-lang/roc/issues/5682
    While Expr Stmt,
]

toValueStr : Value -> Str
toValueStr = \value ->
    when value is
        String s -> "\"\(s)\""
        Number n -> Num.toStr n
        Boolean b -> if b then "true" else "false"
        Nil -> "nil"

toExprStr : Expr -> Str
toExprStr = \outerExpr ->
    when outerExpr is
        Assign { name, value } ->
            "(assign \(name.lexeme) \(toExprStr value)"

        Binary { left, operator, right } ->
            "(\(operator.lexeme) \(toExprStr left) \(toExprStr right))"

        Call { callee, arguments } ->
            argumentsStr = arguments |> List.map toExprStr |> Str.joinWith " "
            "(call \(toExprStr callee) \(argumentsStr))"

        Grouping { expr } ->
            "(group \(toExprStr expr))"

        Literal { value } ->
            toValueStr value

        Logical { left, operator, right } ->
            "(\(operator.lexeme) \(toExprStr left) \(toExprStr right))"

        Unary { operator, expr } ->
            "(\(operator.lexeme) \(toExprStr expr))"

        Variable { name } ->
            name.lexeme

toStmtStr : Stmt -> Str
toStmtStr = \outerStmt ->
    when outerStmt is
        Block { stmts } ->
            parenthesizedStmts =
                stmts
                |> List.map \blockStmt ->
                    blockStmt
                    |> toStmtStr
                    |> indent
                |> Str.joinWith "\n"

            "(block\n\(parenthesizedStmts)\n)"

        Expr { expr } ->
            "(expr \(toExprStr expr))"

        Function { name, params, body } ->
            paramsStr = params |> List.map .lexeme |> Str.joinWith " "
            bodyStr = toStmtStr (Block { stmts: body })
            "(fun \(name.lexeme) \(paramsStr) \(bodyStr))"

        If { condition, thenBranch, elseBranch } ->
            conditionStr = toExprStr condition
            thenStr = toStmtStr thenBranch
            when elseBranch is
                Else elseStmt -> "(if else \(conditionStr) \(thenStr) \(toStmtStr elseStmt))"
                ImplicitNil -> "(if \(conditionStr) \(thenStr))"

        Print { expr } ->
            "(print \(toExprStr expr))"

        Return { value } ->
            when value is
                Value expr -> "(return \(toExprStr expr))"
                ImplicitNil -> "(return nil)"

        Var { name, initializer } ->
            when initializer is
                Value expr -> "(var \(name.lexeme) \(toExprStr expr))"
                ImplicitNil -> "(var \(name.lexeme) nil)"

        While condition body ->
            conditionStr = toExprStr condition
            bodyStr = toStmtStr body
            "(while \(conditionStr) \(bodyStr))"

indent : Str -> Str
indent = \s -> "  \(s)"
