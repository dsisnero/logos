require "./src/logos"

class MyExtras
  property number_count = 0
  property space_count = 0

  def initialize
    @number_count = 0
    @space_count = 0
  end
end

Logos.define MyToken do
  extras MyExtras

  token "if", :If
  regex("[0-9]+", :Number) do |lex|
    lex.extras.number_count += 1
  end

  skip_regex("\\s+", :Whitespace) do |lex|
    lex.extras.space_count += 1
  end
end

# Use lexer iterator
lexer = Logos::Lexer(MyToken, String, MyExtras, Nil).new("if 123", MyExtras.new)
tokens = [] of MyToken
lexer.each do |result|
  tokens << result.unwrap
end

puts "Tokens: #{tokens}"
puts "Extras: number_count=#{lexer.extras.number_count}, space_count=#{lexer.extras.space_count}"

if tokens == [MyToken::If, MyToken::Number] &&
   lexer.extras.number_count == 1 &&
   lexer.extras.space_count == 1
  puts "✓ Test passed"
else
  puts "✗ Test failed"
  exit 1
end
