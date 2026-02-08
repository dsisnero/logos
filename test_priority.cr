require "./src/logos"

module TestPriority
  Logos.define Token do
    regex("[0-9][0-9_]*", :LiteralUnsignedNumber)
    regex("[0-9][0-9_]*\\.[0-9][0-9_]*[TGMKkmupfa]", :LiteralRealNumberDotScaleChar)
    regex("[0-9][0-9_]*\\.[0-9][0-9_]*[eE][+-]?[0-9][0-9_]*", :LiteralRealNumberDotExp)
    regex("[0-9][0-9_]*[TGMKkmupfa]", :LiteralRealNumberScaleChar)
    regex("[0-9][0-9_]*[eE][+-]?[0-9][0-9_]*", :LiteralRealNumberExp)
    regex("[0-9][0-9_]*\\.[0-9][0-9_]*", :LiteralRealNumberDot)
  end
end

lexer = Logos::Lexer(TestPriority::Token, String, Logos::NoExtras, Nil).new("42.42")
puts "Testing input: 42.42"
result = TestPriority::Token.lex(lexer)
puts "Result: #{result.inspect}"
if result
  puts "Token: #{result.unwrap}"
end
puts "Remainder: #{lexer.remainder.inspect}"
puts "Slice: #{lexer.slice.inspect}"
puts "Span: #{lexer.span}"
