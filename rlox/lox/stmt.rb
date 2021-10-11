require_relative "./visitable"

class Stmt < Struct
  include Visitable
end

Stmt.new("Expression", :expr)
Stmt.new("Print", :expr)
