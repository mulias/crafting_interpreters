class Callable
end

class Function < Callable
  attr_reader :arity

  def self.new_built_in(arity, fn_proc)
    new(arity, fn_proc)
  end

  def self.new_fun(declaration, closure)
    new(declaration.params.length, build_proc(declaration, closure))
  end

  def initialize(arity, fn_proc)
    @arity = arity
    @fn = fn_proc
  end

  def call(interpreter, arguments)
    @fn.call(interpreter, arguments)
  end

  private #=====================================================================

  def self.build_proc(declaration, closure)
    Proc.new do |interpreter, arguments|
      environment = Environment.new(closure)

      declaration.params.zip(arguments).each do |param, argument|
        environment.define(param.lexeme, argument)
      end

      catch (:return) do
        interpreter.interpret_block([declaration.body], environment)
      end
    end
  end
end
