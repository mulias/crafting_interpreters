require_relative "./visitable"

class Expr < Struct
  include Visitable
end

Expr.new("Binary", :left_expr, :operator_token, :right_expr)
Expr.new("Grouping", :expr)
Expr.new("Literal", :value)
Expr.new("Unary", :operator_token, :right_expr)
