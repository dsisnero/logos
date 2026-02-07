require "./src/logos"

class MyExtras
  property count = 0

  def initialize
    @count = 0
  end
end

Logos.define MyToken do
  extras MyExtras

  token "if", :If
  token "else", :Else

  # This token should be skipped due to callback returning Skip
  regex("[0-9]+", :Number) do |lex|
    lex.extras.count += 1
    ::Logos::Skip.new
  end

  # This skip token also has callback
  skip_regex("\\s+", :Whitespace) do |lex|
    lex.extras.count += 10
  end
end

lexer = Logos::Lexer(MyToken, String, MyExtras, Nil).new("if 123 else", MyExtras.new)
tokens = [] of MyToken
lexer.each do |result|
  tokens << result.unwrap
end

puts "Tokens: #{tokens}"
puts "Extras count: #{lexer.extras.count}"

# Expected: "if", "else" (number skipped), whitespace skipped
# Extras: number callback increments by 1, whitespace callback increments by 10 (2 whitespaces?)
# Actually whitespace: between "if" and "123", between "123" and "else" -> 2 whitespace tokens
if tokens == [MyToken::If, MyToken::Else] &&
   lexer.extras.count == 21 # 1 (number) + 10 + 10 (two whitespaces)
  puts "✓ Test passed: Skip returned from callback works"
else
  puts "✗ Test failed"
  exit 1
end
