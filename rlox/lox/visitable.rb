# Implements the receiving end of the visitor pattern
module Visitable
  def accept(visitor)
    class_name = self.class.name.downcase.gsub("::", "_")
    visitor.method("visit_#{class_name}").call(self)
  end
end
