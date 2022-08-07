require_relative "./error"

class Environment
  class EnvironmentError < LoxError
    attr_reader :token

    def initialize(token, message)
      super(message)
      @token = token
    end
  end

  def initialize()
    @values = Hash.new()
  end

  def define(name, value)
    @values[name] = value
    nil
  end

  def get(token)
    return @values[token.lexeme] if @values[token.lexeme]

    raise EnvironmentError.new(token, "Undefined variable #{token.lexeme}")
  end
end
