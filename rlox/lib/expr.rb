require_relative "./visitable"

class Expr
  include Visitable

  class Binary < Expr
    attr_reader :left_expr
    attr_reader :operator_token
    attr_reader :right_expr

    def initialize(left_expr, operator_token, right_expr)
      @left_expr = left_expr
      @operator_token = operator_token
      @right_expr = right_expr
    end
  end

  class Grouping < Expr
    attr_reader :expr

    def initialize(expr)
      @expr = expr
    end
  end

  class Literal < Expr
    attr_reader :value

    def initialize(value)
      @value = value
    end
  end

  class Unary < Expr
    attr_reader :operator_token
    attr_reader :right_expr

    def initialize(operator_token, right_expr)
      @operator_token = operator_token
      @right_expr = right_expr
    end
  end

  class Variable < Expr
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end
end
