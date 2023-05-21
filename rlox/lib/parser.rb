require_relative "./expr"
require_relative "./stmt"
require_relative "./error"

class Parser
  class ParseError < LoxError; end

  def initialize()
    starting_state([])
  end

  def parse(tokens)
    starting_state(tokens)

    statements = []

    while !at_end?()
      statements.push(declaration())
    end

    statements
  end

  private #=====================================================================

  def statement()
    return if_statement() if match?(:IF)
    return print_statement() if match?(:PRINT)
    return block() if match?(:LEFT_BRACE)

    expression_statement()
  end

  def if_statement()
    consume(:LEFT_PAREN, "Expect '(' after 'if'.")
    condition = expression
    consume(:RIGHT_PAREN, "Expect ')' after if condition.")

    then_branch = statement()
    else_branch = statement() if match?(:ELSE)

    Stmt::If.new(condition, then_branch, else_branch)
  end

  def print_statement()
    expr = expression()
    consume(:SEMICOLON, "Expect ';' after value.")
    Stmt::Print.new(expr)
  end

  def var_declaration()
    name = consume(:IDENTIFIER, "Expect variable name")
    initializer = match?(:EQUAL) ? expression() : nil

    consume(:SEMICOLON, "Expect ';' after variable declaration.")
    Stmt::Var.new(name, initializer)
  end

  def expression_statement()
    expr = expression()
    consume(:SEMICOLON, "Expect ';' after value.")
    Stmt::Expression.new(expr)
  end

  def block()
    statements = []

    while !check?(:RIGHT_BRACE) && !at_end?()
      statements.push(declaration())
    end

    consume(:RIGHT_BRACE, "Expect '}' after block.")

    Stmt::Block.new(statements)
  end

  def assignment()
    expr = logical_or()

    if match?(:EQUAL)
      equals = previous()
      value = assignment()

      if expr.instance_of?(Expr::Variable)
        return Expr::Assign.new(expr.name, value)
      end

      error(equals, "Invalid assignment target.")
    end

    expr
  end

  def logical_or()
    expr = logical_and()

    while match?(:OR)
      operator = previous()
      right = logical_and()
      expr = Expr::Logical.new(expr, operator, right)
    end

    expr
  end

  def logical_and()
    expr = equality()

    while match?(:AND)
      operator = previous()
      right = equality()
      expr = Expr::Logical.new(expr, operator, right)
    end

    expr
  end

  def expression()
    assignment()
  end

  def declaration()
    begin
      if match?(:VAR)
        return var_declaration()
      end
      statement()
    rescue ParseError => e
      syncronize()
      nil
    end
  end

  def equality()
    binary_expr(:comparison, [:BANG_EQUAL, :EQUAL_EQUAL], :comparison)
  end

  def comparison()
    binary_expr(:term, [:GREATER, :GREATER_EQUAL, :LESS, :LESS_EQUAL], :term)
  end

  def term()
    binary_expr(:factor, [:MINUS, :PLUS], :factor)
  end

  def factor()
    binary_expr(:unary, [:SLASH, :STAR], :unary)
  end

  def unary()
    if match?(:BANG, :MINUS)
      operator_token = previous()
      right_expr = unary()
      return Expr::Unary.new(operator_token, right_expr)
    end
    primary()
  end

  def primary()
    return Expr::Literal.new(false) if match?(:FALSE)
    return Expr::Literal.new(true) if match?(:TRUE)
    return Expr::Literal.new(nil) if match?(:NIL)
    return Expr::Literal.new(previous().literal) if match?(:NUMBER, :STRING)
    return Expr::Variable.new(previous()) if match?(:IDENTIFIER)

    if match?(:LEFT_PAREN)
      expr = expression()
      consume(:RIGHT_PAREN, "Expect ')' after expression.")
      return Expr::Grouping.new(expr)
    end

    raise error(peek(), "Expected expression")
  end

  def binary_expr(left_parser, tokens, right_parser)
    expr = method(left_parser).call()
    while match?(*tokens)
      operator_token = previous()
      right_expr = method(right_parser).call()
      expr = Expr::Binary.new(expr, operator_token, right_expr)
    end
    expr
  end

  def match?(*token_types)
    if token_types.any? { |type| check?(type) }
      advance()
      true
    else
      false
    end
  end

  def check?(type)
    return false if at_end?()
    peek().type?(type)
  end

  def advance()
    @tokens_pos += 1 if !at_end?()
    return previous()
  end

  def at_end?()
    peek().type?(:EOF)
  end

  def peek()
    @tokens[@tokens_pos]
  end

  def previous()
    @tokens[@tokens_pos - 1]
  end

  def consume(type, error_message)
    return advance() if check?(type)

    raise error(peek(), error_message)
  end

  def error(token, error_message)
    Lox.error(token, error_message)
    return ParseError.new()
  end

  def syncronize()
    advance()
    while !at_end?()
      return if previous().type?(:SEMICOLON)

      case peek().type
      when :CLASS, :FOR, :FUN, :IF, :PRINT, :RETURN, :VAR, :WHILE
        return
      end
    end

    advance()
  end

  def starting_state(tokens)
    @tokens = tokens
    @tokens_pos = 0
  end
end
