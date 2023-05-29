class Resolver
  class ResolverError < LoxError
    attr_reader :token

    def initialize(token, message)
      super(message)
      @token = token
    end
  end

  def initialize(interpreter)
    @interpreter = interpreter
    @scopes = []
    @current_function_type = :none
  end

  def resolve(statements)
    statements.each { |stmt| visit(stmt) }
  end

  def visit_stmt_block(stmt)
    begin_scope()
    stmt.statements.each { |stmt| visit(stmt) }
    end_scope()
    nil
  end

  def visit_stmt_print(stmt)
    visit(stmt.expr)
    nil
  end

  def visit_stmt_return(stmt)
    if @current_function_type == :none
      raise ResolverError.new(stmt.keyword, "Can't return from top-level code.")
    end

    visit(stmt.value) if stmt.value
    nil
  end

  def visit_stmt_var(stmt)
    declare(stmt.name)
    visit(stmt.initializer) if stmt.initializer
    define(stmt.name)
    nil
  end

  def visit_stmt_while(stmt)
    visit(stmt.condition)
    visit(stmt.body)
    nil
  end

  def visit_stmt_expression(stmt)
    visit(stmt.expr)
    nil
  end

  def visit_stmt_function(stmt)
    declare(stmt.name)
    define(stmt.name)

    resolve_function(stmt, :function)
    nil
  end

  def visit_stmt_if(stmt)
    visit(stmt.condition)
    visit(stmt.then_branch)
    visit(stmt.else_branch) if stmt.else_branch
    nil
  end

  def visit_expr_assign(expr)
    visit(expr.value)
    resolve_local(expr, expr.name)
    nil
  end

  def visit_expr_binary(expr)
    visit(expr.left_expr)
    visit(expr.right_expr)
    nil
  end

  def visit_expr_call(expr)
    visit(expr.callee)
    expr.arguments.each { |argument| visit(argument) }
    nil
  end

  def visit_expr_grouping(expr)
    visit(expr.expr)
  end

  def visit_expr_literal(expr)
    nil
  end

  def visit_expr_logical(expr)
    visit(expr.left_expr)
    visit(expr.right_expr)
    nil
  end

  def visit_expr_unary(expr)
    visit(expr.right_expr)
    nil
  end

  def visit_expr_variable(expr)
    if @scopes.any? && @scopes.last[expr.name.lexeme] == false
      raise ResolverError.new(expr.name, "Can't read local variable in its own initializer.")
    end

    resolve_local(expr, expr.name)
    nil
  end

  private #=====================================================================

  def visit(stmt_or_expr)
    stmt_or_expr.accept(self)
  end

  def begin_scope()
    @scopes.push({})
  end

  def end_scope()
    @scopes.pop()
  end

  def declare(name)
    return if @scopes.empty?

    scope = @scopes.last

    if scope[name.lexeme]
      raise ResolverError(name, "Already a variable with this name in this scope.")
    end

    scope[name.lexeme] = false
  end

  def define(name)
    return if @scopes.empty?
    @scopes.last[name.lexeme] = true
  end

  def resolve_local(expr, name)
    @scopes.to_enum.with_index.reverse_each do |scope, idx|
      if scope[name.lexeme]
        @interpreter.resolve(expr, @scopes.length - 1 - idx)
        break
      end
    end
  end

  def resolve_function(function, type)
    enclosing_function_type = @current_function_type
    @current_function_type = type

    begin_scope()
    function.params.each do |param|
      declare(param)
      define(param)
    end
    visit(function.body)
    end_scope()

    @current_function_type = enclosing_function_type
  end
end
