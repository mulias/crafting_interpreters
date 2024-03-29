require_relative "./visitable"

class Expr
  include Visitable

  class Assign < Expr
    attr_reader :name
    attr_reader :value

    def initialize(name, value)
      @name = name
      @value = value
    end
  end

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

  class Call < Expr
    attr_reader :callee
    attr_reader :paren
    attr_reader :arguments

    def initialize(callee, paren, arguments)
      @callee = callee
      @paren = paren
      @arguments = arguments
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

  class Logical < Expr
    attr_reader :left_expr
    attr_reader :operator
    attr_reader :right_expr

    def initialize(left_expr, operator, right_expr)
      @left_expr = left_expr
      @operator = operator
      @right_expr = right_expr
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
