require_relative "./callable"

class Globals < Environment
  def initialize()
    @values = Hash.new()
    @enclosing = nil
    set_globals()
  end

  private #=====================================================================

  def set_globals()
    define("clock", Function.new_built_in(
      0, Proc.new { (Time.now.to_f * 1000).to_i },
    ))
  end
end
