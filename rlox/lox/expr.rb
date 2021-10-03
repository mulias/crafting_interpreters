class Expr < Struct
  # Implement the visitor pattern, an expr visitor must implement the methods
  # `visitBinaryExpr`, `visitGroupingExpr` etc.
  def accept(visitor)
    expr_name = self.class.name.split("::").last
    visitor.method("visit#{expr_name}Expr").call(self)
  end
end

Binary = Expr.new(:left_expr, :operator_token, :right_expr)
Grouping = Expr.new(:expr)
Literal = Expr.new(:value)
Unary = Expr.new(:operator_token, :right_expr)
