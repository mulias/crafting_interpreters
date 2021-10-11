require_relative "./error"

# Implements the visitor pattern for `Stmt` and `Expr` objects.
class Interpreter
  class InterpreterError < LoxError
    attr_reader :token

    def initialize(token, message)
      super(message)
      @token = token
    end
  end

  def interpret(statements)
    begin
      statements.each { |stmt| evaluate(stmt) }
    rescue InterpreterError => e
      Lox.runtime_error(e.token, e.message)
    end
  end

  def visit_stmt_print(stmt)
    val = evaluate(stmt.expr)
    puts(stringify(val))
  end

  def visit_stmt_expression(stmt)
    evaluate(stmt.expr)
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
    when :BANG_EQUAL; !is_equal(left, right)
    when :EQUAL_EQUAL; is_equal(left, right)
    end
  end

  def visit_expr_grouping(expr)
    evaluate(expr.expr)
  end

  def visit_expr_literal(expr)
    expr.value
  end

  def visit_expr_unary(expr)
    right = evaluate(expr.right_expr)

    case expr.operator_token.type
    when :MINUS
      check_number_operand(expr.operator_token, right)
      -right
    when :BANG; !is_truthy(right)
    end
  end

  private

  def evaluate(expr_or_stmt)
    expr_or_stmt.accept(self)
  end

  def stringify(lox_val)
    return "nil" if lox_val.nil?

    if lox_val.is_a?(Numeric)
      text = lox_val.to_s
      if text.end_with?(".0")
        text = text[0...-2]
      end
      return text
    end

    lox_val.to_s
  end

  def is_truthy(val)
    return false if val.nil?
    return false if val.is_a?(FalseClass)
    true
  end

  def is_equal(a, b)
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
