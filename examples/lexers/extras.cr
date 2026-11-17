require "../../src/logos"

class PositionExtras
  property line : Int32
  property line_start : Int32

  def initialize
    @line = 1
    @line_start = 0
  end
end

Logos.define Token do
  extras PositionExtras
  error_type Nil

  skip_regex "\n", :Newline do |lex|
    lex.extras.line += 1
    lex.extras.line_start = lex.span.end
    Logos::Skip.new
  end

  regex "\\w+", :Word do |lex|
    line = lex.extras.line
    column = lex.span.begin - lex.extras.line_start
    Logos::Filter::Emit.new({line, column})
  end
end
