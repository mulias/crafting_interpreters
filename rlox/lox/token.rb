Token = Struct.new(:type, :lexeme, :literal, :line_num) do
  def type?(test)
    type == test
  end

  def to_s
    "#{type} #{lexeme} #{literal}"
  end
end
