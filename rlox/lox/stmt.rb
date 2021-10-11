class Stmt < Struct
  # Implement the visitor pattern, a stmt visitor must implement the methods
  # `visitExpressionStmt`, `visitPrintStmt` etc.
  def accept(visitor)
    class_name = self.class.name.gsub("::", "")
    visitor.method("visit#{class_name}").call(self)
  end
end

Stmt.new("Expression", :expr)
Stmt.new("Print", :expr)
