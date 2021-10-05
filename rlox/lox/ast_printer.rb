# Implements the visitor pattern for `Expr` objects.
class AstPrinter
  def print(expr)
    expr.accept(self)
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
