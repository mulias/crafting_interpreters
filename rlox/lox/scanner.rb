require_relative "./token"

class Scanner
  def initialize(source)
    @source = source
    @tokens = []
    @start_pos = 0
    @current_pos = 0
    @line_num = 1
  end

  def scan_tokens()
    while !is_at_end()
      @start_pos = @current_pos
      scan_token()
    end

    @start_pos = @current_pos
    add_token(:EOF)

    @tokens
  end

  private

  def is_at_end()
    @current_pos >= @source.length
  end

  def scan_token()
    char = advance()
    case char
    when "("; add_token(:LEFT_PAREN)
    when ")"; add_token(:RIGHT_PAREN)
    when "{"; add_token(:LEFT_BRACE)
    when "}"; add_token(:RIGHT_BRACE)
    when ","; add_token(:COMMA)
    when "."; add_token(:DOT)
    when "-"; add_token(:MINUS)
    when "+"; add_token(:PLUS)
    when ";"; add_token(:SEMICOLON)
    when "*"; add_token(:STAR)
    when "!"; match("=") ? add_token(:BANG_EQUAL) : add_token(:BANG)
    when "="; match("=") ? add_token(:EQUAL_EQUAL) : add_token(:EQUAL)
    when "<"; match("=") ? add_token(:LESS_EQUAL) : add_token(:LESS)
    when ">"; match("=") ? add_token(:GREATER_EQUAL) : add_token(:GREATER)
    when "/"; match("/") ? comment() : add_token(:SLASH)
    when try(:is_whitespace); @tokens
    when "\n"; @line_num += 1; @tokens
    when "\""; string()
    when try(:is_digit); number()
    when try(:is_alpha); identifier()
    else Lox.error(@line_num, "Unexpected character #{char}.")
    end
  end

  def is_whitespace(char)
    [" ", "\r", "\t"].member?(char)
  end

  def is_digit(char)
    ("0".."9").member?(char)
  end

  def is_alpha(char)
    (char >= "a" && char <= "z") ||
    (char >= "A" && char <= "Z") ||
    char == "_"
  end

  def is_alpha_numeric(char)
    is_alpha(char) || is_digit(char)
  end

  def comment()
    advance() while peek() != "\n" && !is_at_end()
    @tokens
  end

  def string()
    while peek() != "\"" && !is_at_end()
      @line_num += 1 if peek() == "\n"
      advance()
    end

    if is_at_end()
      Lox.error(@line_num, "Unterminated string.")
      return @tokens
    end

    advance() # Consume the closing ".

    add_token(:STRING, token_text()[1...-1])
  end

  def number()
    advance() while is_digit(peek())

    # Look for a fractional part.
    if peek() == "." && is_digit(peek_next())
      advance() # Consume the dot.
      advance() while is_digit(peek())
    end

    add_token(:NUMBER, token_text().to_f)
  end

  def identifier()
    advance() while is_alpha_numeric(peek())

    keywords = %w(
      and class else false for fun if nil or
      print return super this true var while
    )
    text = token_text()
    type = keywords.member?(text) ? text.upcase.to_sym : :IDENTIFIER

    add_token(type)
  end

  def token_text()
    @source[@start_pos...@current_pos]
  end

  def add_token(type, literal = nil)
    @tokens.push(Token.new(type, token_text(), literal, @line_num))
  end

  def advance()
    char = @source[@current_pos] || ""
    @current_pos += 1
    char
  end

  def match(expected)
    return false if is_at_end()
    return false if @source[@current_pos] != expected

    @current_pos += 1
    true
  end

  def peek()
    @source[@current_pos] || ""
  end

  def peek_next()
    @source[@current_pos + 1] || ""
  end

  def try(method_name)
    lambda(&method(method_name))
  end
end
