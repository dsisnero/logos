require "./src/logos"
require "./spec/logos/edgecase_spec"

module TestSkip
  Logos.define Token do
    skip_regex " +", :Whitespace
    regex("[0-9]+", :Number)
  end
end

lexer = Logos::Lexer(TestSkip::Token, String, Logos::NoExtras, Nil).new(" 123")
puts "Remainder: #{lexer.remainder.inspect}"
result = TestSkip::Token.lex(lexer)
puts "Result: #{result.inspect}"
puts "Remainder after: #{lexer.remainder.inspect}"
