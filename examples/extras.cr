# Print line and column positions for each word in a file.
#
# Usage:
#   crystal run examples/extras.cr -- <path/to/file>

require "../src/logos"

{% if flag?(:precompiled) %}
  require "generated_token"
{% end %}

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

if ARGV.empty?
  abort "Expected file argument"
end

source = File.read(ARGV.first)
lex = Token.lexer_with_extras(source, PositionExtras.new)

lex.each do |result|
  if position = result.payload_for(Token::Word, Tuple(Int32, Int32))
    line, column = position
    puts "Word '#{lex.slice}' found at (#{line}, #{column})"
  end
end
