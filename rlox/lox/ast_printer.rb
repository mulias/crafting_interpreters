# Implements the visitor pattern for `Stmt` and `Expr` objects.
class AstPrinter
  def print(statements)
    puts("--- AST PRINTER ---")
    statements.each { |stmt| puts stmt.accept(self) }
    puts("--- AST PRINTER ---\n\n")
  end

  def visitStmtPrint(stmt)
    parenthesize("print", stmt.expr)
  end

  def visitStmtExpression(stmt)
    parenthesize("expr", stmt.expr)
  end

  def visitBinaryExpr(expr)
    parenthesize(expr.operator_token.lexeme, expr.left_expr, expr.right_expr)
  end

  def visitGroupingExpr(expr)
    parenthesize("group", expr.expr)
  end

  def visitLiteralExpr(expr)
    return "nil" if expr.value == nil
    expr.value.to_s
  end

  def visitUnaryExpr(expr)
    parenthesize(expr.operator_token.lexeme, expr.right_expr)
  end

  private

  def parenthesize(name, *exprs)
    parenthesized_exprs = exprs
      .map { |expr| expr.accept(self) }
      .join(" ")

    "(#{name} #{parenthesized_exprs})"
  end
end
