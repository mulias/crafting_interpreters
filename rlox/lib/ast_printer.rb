class AstPrinter
  def print(statements)
    puts("--- AST PRINTER ---")
    statements.each { |stmt| puts stmt.accept(self) }
    puts("--- AST PRINTER ---\n\n")
  end

  def visit_stmt_block(stmt)
    parenthesize_block(stmt.statements)
  end

  def visit_stmt_print(stmt)
    parenthesize("print", stmt.expr)
  end

  def visit_stmt_var(stmt)
    parenthesize("var #{stmt.name.lexeme}", stmt.initializer)
  end

  def visit_stmt_while(stmt)
    parenthesize("while", stmt.condition, stmt.body)
  end

  def visit_stmt_expression(stmt)
    parenthesize("expr", stmt.expr)
  end

  def visit_stmt_if(stmt)
    if stmt.else_branch
      parenthesize("if else", stmt.condition, stmt.then_branch, stmt.else_branch)
    else
      parenthesize("if", stmt.condition, stmt.then_branch)
    end
  end

  def visit_expr_assign(expr)
    parenthesize("assign #{expr.name.lexeme}", expr.value)
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

  def visit_expr_logical(expr)
    if expr.operator.type?(:OR)
      parenthesize("or", expr.left_expr, expr.right_expr)
    else
      parenthesize("and", expr.left_expr, expr.right_expr)
    end
  end

  def visit_expr_unary(expr)
    parenthesize(expr.operator_token.lexeme, expr.right_expr)
  end

  def visit_expr_variable(expr)
    expr.name.lexeme
  end

  private #=====================================================================

  def parenthesize(name, *visitables)
    parenthesized = visitables
      .map { |visitable| visitable.accept(self) }
      .join(" ")

    "(#{name} #{parenthesized})"
  end

  def parenthesize_block(statements)
    parenthesized_stmts = statements
      .map { |stmt| indent(stmt.accept(self)) }
      .join("\n")

    "(block\n#{parenthesized_stmts}\n)"
  end

  def indent(lines)
    lines.split("\n").map { |line| "  " + line }.join("\n")
  end
end
