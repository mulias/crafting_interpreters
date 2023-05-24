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

  class Function < Stmt
    attr_reader :name
    attr_reader :params
    attr_reader :body

    def initialize(name, params, body)
      @name = name
      @params = params
      @body = body
    end
  end

  class If < Stmt
    attr_reader :condition
    attr_reader :then_branch
    attr_reader :else_branch

    def initialize(condition, then_branch, else_branch)
      @condition = condition
      @then_branch = then_branch
      @else_branch = else_branch
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

  class While < Stmt
    attr_reader :condition
    attr_reader :body

    def initialize(condition, body)
      @condition = condition
      @body = body
    end
  end
end
