# Print line and column positions for each word in a file.
#
# Usage:
#   crystal run examples/extras.cr -- <path/to/file>

require "./lexers/extras"

{% if flag?(:precompiled) %}
  require "generated_token"
{% end %}

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
