require_relative "./error"

class Environment
  class EnvironmentError < LoxError
    attr_reader :token

    def initialize(token, message)
      super(message)
      @token = token
    end
  end

  def initialize(enclosing_env = nil)
    @values = Hash.new()
    @enclosing = enclosing_env
  end

  def define(name, value)
    @values[name] = value
    nil
  end

  def get(token)
    return @values[token.lexeme] if @values.member?(token.lexeme)
    return @enclosing.get(token) if @enclosing

    raise EnvironmentError.new(token, "Undefined variable #{token.lexeme}.")
  end

  def assign(name, value)
    return @values[name.lexeme] = value if @values.member?(name.lexeme)
    return @enclosing.assign(name, value) if @enclosing

    raise EnvironmentError.new(token, "Undefined variable #{token.lexeme}.")
  end
end
