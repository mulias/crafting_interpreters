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
    return for_statement() if match?(:FOR)
    return if_statement() if match?(:IF)
    return print_statement() if match?(:PRINT)
    return return_statement() if match?(:RETURN)
    return while_statement() if match?(:WHILE)
    return block() if match?(:LEFT_BRACE)

    expression_statement()
  end

  def for_statement()
    consume(:LEFT_PAREN, "Expect '(' after 'for'.")

    initializer = if match?(:SEMICOLON)
        nil
      elsif match?(:VAR)
        var_declaration()
      else
        expression_statement()
      end

    condition = if check?(:SEMICOLON)
        Expr::Literal.new(true)
      else
        expression()
      end

    consume(:SEMICOLON, "Expect ';' after loop condition.")

    increment = expression() unless check?(:RIGHT_PAREN)

    consume(:RIGHT_PAREN, "Expect ')' after for clauses.")

    body = statement()

    for_stmt = if increment
        Stmt::While.new(
          condition,
          Stmt::Block.new([
            body,
            Stmt::Expression.new(increment),
          ])
        )
      else
        Stmt::While.new(condition, body)
      end

    if initializer
      Stmt::Block.new([initializer, for_stmt])
    else
      for_stmt
    end
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

  def return_statement()
    keyword = previous()
    value = expression() unless check?(:SEMICOLON)

    consume(:SEMICOLON, "Expect ';' after return value.")
    Stmt::Return.new(keyword, value)
  end

  def var_declaration()
    name = consume(:IDENTIFIER, "Expect variable name")
    initializer = match?(:EQUAL) ? expression() : nil

    consume(:SEMICOLON, "Expect ';' after variable declaration.")
    Stmt::Var.new(name, initializer)
  end

  def while_statement()
    consume(:LEFT_PAREN, "Expect '(' after 'while'.")
    condition = expression()
    consume(:RIGHT_PAREN, "Expect ')' after 'condition'.")
    body = statement()

    Stmt::While.new(condition, body)
  end

  def expression_statement()
    expr = expression()
    consume(:SEMICOLON, "Expect ';' after value.")
    Stmt::Expression.new(expr)
  end

  def function(kind)
    name = consume(:IDENTIFIER, "Expect #{kind} name.")
    consume(:LEFT_PAREN, "Expect '(' after #{kind} name.")
    parameters = []
    unless check?(:RIGHT_PAREN)
      parameters.push(consume(:IDENTIFIER, "Expect parameter name."))
      while match?(:COMMA)
        if parameters.length >= 255
          error(peek(), "Can't have more than 255 parameters.")
        end
        parameters.push(consume(:IDENTIFIER, "Expect parameter name."))
      end
    end
    consume(:RIGHT_PAREN, "Expect ')' after parameters.")

    consume(:LEFT_BRACE, "Expect '{' before #{kind} body.")
    body = block()
    Stmt::Function.new(name, parameters, body)
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
    left_expr = logical_and()

    while match?(:OR)
      operator = previous()
      right = logical_and()
      expr = Expr::Logical.new(left_expr, operator, right)
    end

    expr || left_expr
  end

  def logical_and()
    left_expr = equality()

    while match?(:AND)
      operator = previous()
      right = equality()
      expr = Expr::Logical.new(left_expr, operator, right)
    end

    expr || left_expr
  end

  def expression()
    assignment()
  end

  def declaration()
    begin
      return function("function") if match?(:FUN)
      return var_declaration() if match?(:VAR)
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
    call()
  end

  def call()
    callee = primary()

    while match?(:LEFT_PAREN)
      expr = finish_call(callee)
    end

    expr || callee
  end

  def finish_call(callee)
    arguments = []

    unless check?(:RIGHT_PAREN)
      arguments.push(expression())
      while match?(:COMMA)
        if arguments.length >= 255
          error(peek(), "Can't have more than 255 arguments")
        end
        arguments.push(expression())
      end
    end

    paren = consume(:RIGHT_PAREN, "Expect ')' after arguments.")

    Expr::Call.new(callee, paren, arguments)
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
