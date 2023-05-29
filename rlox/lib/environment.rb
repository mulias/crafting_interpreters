require_relative "./error"

class Environment
  class EnvironmentError < LoxError
    attr_reader :token

    def initialize(token, message)
      super(message)
      @token = token
    end
  end

  attr_reader :values
  attr_reader :enclosing

  def initialize(enclosing_env = nil)
    @values = Hash.new()
    @enclosing = enclosing_env
  end

  def define(name, value)
    @values[name] = value
    nil
  end

  def ancestor(distance)
    if distance == 0
      @values
    else
      environment = @enclosing
      (1...distance).each do
        environment = environment.enclosing if environment.enclosing
      end
      environment.values
    end
  end

  def get(token)
    return @values[token.lexeme] if @values.member?(token.lexeme)
    return @enclosing.get(token) if @enclosing

    raise EnvironmentError.new(token, "Undefined variable #{token.lexeme}.")
  end

  def get_at(distance, name)
    ancestor(distance)[name.lexeme]
  end

  def assign(name, value)
    return @values[name.lexeme] = value if @values.member?(name.lexeme)
    return @enclosing.assign(name, value) if @enclosing

    raise EnvironmentError.new(name, "Undefined variable #{name.lexeme}.")
  end

  def assign_at(distance, name, value)
    ancestor(distance)[name.lexeme] = value
  end

  def to_s
    "{env: #{@values.to_s}, enclosing: #{@enclosing || "{}"}}"
  end
end
