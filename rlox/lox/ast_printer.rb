class AstPrinter
  # Implements the visitor pattern for `Expr` objects.

  def self.print(expr)
    expr.accept(self)
  end

  def self.visitBinaryExpr(expr)
    parenthesize(expr.operator_token.lexeme, expr.left_expr, expr.right_expr)
  end

  def self.visitGroupingExpr(expr)
    parenthesize("group", expr.expr)
  end

  def self.visitLiteralExpr(expr)
    return "nil" if expr.value == nil
    expr.value.to_s
  end

  def self.visitUnaryExpr(expr)
    parenthesize(expr.operator_token.lexeme, expr.right_expr)
  end

  private

  def self.parenthesize(name, *exprs)
    parenthesized_exprs = exprs.map { |expr| expr.accept(self) }
    "(#{name} #{parenthesized_exprs.join(" ")})"
  end
end
