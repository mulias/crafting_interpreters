require_relative "./visitable"

class Stmt
  include Visitable

  class Block < Stmt
    attr_reader :statements

    def initialize(statements)
      @statements = statements
    end
  end

  class Expression < Stmt
    attr_reader :expr

    def initialize(expr)
      @expr = expr
    end
  end

  class Print < Stmt
    attr_reader :expr

    def initialize(expr)
      @expr = expr
    end
  end

  class Var < Stmt
    attr_reader :name
    attr_reader :initializer

    def initialize(name, initializer)
      @name = name
      @initializer = initializer
    end
  end
end
