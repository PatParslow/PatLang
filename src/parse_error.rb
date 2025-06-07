# ParseError class for handling parser-specific errors
class ParseError < StandardError
  attr_reader :line, :column, :position, :token
  
  def initialize(message, line: nil, column: nil, position: nil, token: nil)
    super(message)
    @line = line
    @column = column  
    @position = position
    @token = token
  end
  
  def to_s
    if @line && @column
      "#{super} at line #{@line}, column #{@column}"
    elsif @position
      "#{super} at position #{@position}"
    else
      super
    end
  end
end