class Token
  attr_reader :type
  attr_reader :lexeme
  attr_reader :literal
  attr_reader :line_num

  def initialize(type, lexeme, literal, line_num)
    @type = type
    @lexeme = lexeme
    @literal = literal
    @line_num = line_num
  end

  def type?(test)
    type == test
  end

  def to_s
    "#{type} #{lexeme} #{literal}"
  end
end
