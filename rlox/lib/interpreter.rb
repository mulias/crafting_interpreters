require_relative "./error"
require_relative "./environment"
require_relative "./globals"

class Interpreter
  class InterpreterError < LoxError
    attr_reader :token

    def initialize(token, message)
      super(message)
      @token = token
    end
  end

  def initialize()
    globals = Globals.new()
    @environment = globals
    @globals = globals
    @locals = {}
  end

  def interpret(statements)
    begin
      statements.each { |stmt| evaluate(stmt) }
    rescue InterpreterError => e
      Lox.runtime_error(e.token, e.message)
    rescue Environment::EnvironmentError => e
      Lox.runtime_error(e.token, e.message)
    end
  end

  def interpret_block(statements, environment)
    previous = @environment
    @environment = environment
    statements.each { |stmt| evaluate(stmt) }
  ensure
    @environment = previous
  end

  def resolve(expr, depth)
    @locals[expr] = depth
    nil
  end

  def visit_stmt_block(stmt)
    interpret_block(stmt.statements, Environment.new(@environment))
    nil
  end

  def visit_stmt_print(stmt)
    val = evaluate(stmt.expr)
    puts(stringify(val))
  end

  def visit_stmt_return(stmt)
    value = evaluate(stmt.value) if stmt.value
    throw(:return, value)
  end

  def visit_stmt_var(stmt)
    value = case stmt.initializer
      when Expr
        evaluate(stmt.initializer)
      when nil
        nil
      end

    @environment.define(stmt.name.lexeme, value)
    nil
  end

  def visit_stmt_while(stmt)
    while truthy?(evaluate(stmt.condition))
      evaluate(stmt.body)
    end
    nil
  end

  def visit_stmt_expression(stmt)
    evaluate(stmt.expr)
  end

  def visit_stmt_function(stmt)
    @environment.define(stmt.name.lexeme, Function.new_fun(stmt, @environment))
    nil
  end

  def visit_stmt_if(stmt)
    if truthy?(evaluate(stmt.condition))
      evaluate(stmt.then_branch)
    elsif stmt.else_branch
      evaluate(stmt.else_branch)
    end

    nil
  end

  def visit_expr_assign(expr)
    value = evaluate(expr.value)

    distance = @locals[expr]
    if distance
      @environment.assign_at(distance, expr.name, value)
    else
      @globals.assign(expr.name, value)
    end

    value
  end

  def visit_expr_binary(expr)
    operator = expr.operator_token
    left = evaluate(expr.left_expr)
    right = evaluate(expr.right_expr)

    case operator.type
    when :GREATER
      check_number_operands(operator, left, right)
      left > right
    when :GREATER_EQUAL
      check_number_operands(operator, left, right)
      left >= right
    when :LESS
      check_number_operands(operator, left, right)
      left < right
    when :LESS_EQUAL
      check_number_operands(operator, left, right)
      left <= right
    when :MINUS
      check_number_operands(operator, left, right)
      left - right
    when :SLASH
      check_number_operands(operator, left, right)
      left / right
    when :STAR
      check_number_operands(operator, left, right)
      left * right
    when :PLUS
      check_number_or_string_operands(operator, left, right)
      left + right
    when :BANG_EQUAL; !equal?(left, right)
    when :EQUAL_EQUAL; equal?(left, right)
    end
  end

  def visit_expr_call(expr)
    callee = evaluate(expr.callee)
    arguments = expr.arguments.map { |arg| evaluate(arg) }

    unless callee.is_a?(Callable)
      raise InterpreterError.new(expr.paren, "Can only call functions and classes")
    end

    unless arguments.length == callee.arity
      raise InterpreterError.new(expr.paren, "Expected #{callee.arity} arguments but got #{arguments.length}.")
    end

    callee.call(self, arguments)
  end

  def visit_expr_grouping(expr)
    evaluate(expr.expr)
  end

  def visit_expr_literal(expr)
    expr.value
  end

  def visit_expr_logical(expr)
    left = evaluate(expr.left_expr)

    if expr.operator.type?(:OR)
      return left if truthy?(left)
    else
      return left if !truthy?(left)
    end

    evaluate(expr.right_expr)
  end

  def visit_expr_unary(expr)
    right = evaluate(expr.right_expr)

    case expr.operator_token.type
    when :MINUS
      check_number_operand(expr.operator_token, right)
      -right
    when :BANG; !truthy?(right)
    end
  end

  def visit_expr_variable(expr)
    look_up_variable(expr.name, expr)
  end

  private #=====================================================================

  def evaluate(expr_or_stmt)
    expr_or_stmt.accept(self)
  end

  def look_up_variable(name, expr)
    distance = @locals[expr]
    if distance
      @environment.get_at(distance, name)
    else
      @globals.get(name)
    end
  end

  def stringify(lox_val)
    return "nil" if lox_val.nil?

    if lox_val.is_a?(Numeric)
      text = lox_val.to_s
      if text.end_with?(".0")
        text = text[0...-2]
      end
      return text.to_s
    end

    lox_val.to_s
  end

  def truthy?(val)
    return false if val.nil?
    return false if val.is_a?(FalseClass)
    true
  end

  def equal?(a, b)
    a.eql?(b)
  end

  def check_number_operand(operator, operand)
    return if operand.is_a?(Numeric)
    raise InterpreterError.new(operator, "Operand must be a number.")
  end

  def check_number_operands(operator, left, right)
    return if left.is_a?(Numeric) && right.is_a?(Numeric)
    raise InterpreterError.new(operator, "Operands must be numbers.")
  end

  def check_number_or_string_operands(operator, left, right)
    return if left.is_a?(Numeric) && right.is_a?(Numeric)
    return if left.is_a?(String) && right.is_a?(String)
    raise InterpreterError.new(operator, "Operands must be two numbers or two strings.")
  end
end
