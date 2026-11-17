# ASCII tokens lexer with custom error type.
#
# Usage:
#   crystal run examples/custom_error.cr -- [input]

require "./lexers/custom_error"

{% if flag?(:precompiled) %}
  require "generated_token_with_error"
{% end %}

lex = Token.lexer(ARGV.first? || "Hello 256 Jérome")

while token = lex.next
  break if token.is_a?(Iterator::Stop)
  result = token.as(Logos::Result(Token, LexingError))
  if result.ok?
    case result.unwrap
    when Token::Word
      puts "Word: #{lex.slice}"
    when Token::Integer
      puts "Integer: #{result.payload_for!(Token::Integer, UInt8)}"
    else
      # Skip
    end
  else
    puts "Error: #{result.unwrap_error} (slice=#{lex.slice})"
  end
end
