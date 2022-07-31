# Implements the visitor pattern for `Stmt` and `Expr` objects.
class AstPrinter
  def print(statements)
    puts("--- AST PRINTER ---")
    statements.each { |stmt| puts stmt.accept(self) }
    puts("--- AST PRINTER ---\n\n")
  end

  def visit_stmt_print(stmt)
    parenthesize("print", stmt.expr)
  end

  def visit_stmt_var(stmt)
    parenthesize("var #{stmt.name.lexeme}", stmt.initializer)
  end

  def visit_stmt_expression(stmt)
    parenthesize("expr", stmt.expr)
  end

  def visit_expr_binary(expr)
    parenthesize(expr.operator_token.lexeme, expr.left_expr, expr.right_expr)
  end

  def visit_expr_grouping(expr)
    parenthesize("group", expr.expr)
  end

  def visit_expr_literal(expr)
    return "nil" if expr.value == nil
    expr.value.to_s
  end

  def visit_expr_unary(expr)
    parenthesize(expr.operator_token.lexeme, expr.right_expr)
  end

  def visit_expr_variable(expr)
    expr.name
  end

  private

  def parenthesize(name, *exprs)
    parenthesized_exprs = exprs
      .map { |expr| expr.accept(self) }
      .join(" ")

    "(#{name} #{parenthesized_exprs})"
  end
end
