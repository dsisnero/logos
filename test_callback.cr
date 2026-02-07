require "./src/logos"

class MyExtras
  property number_count = 0
  property space_count = 0
  property total_chars = 0

  def initialize
    @number_count = 0
    @space_count = 0
    @total_chars = 0
  end
end

Logos.define MyToken do
  extras MyExtras

  token "if", :If
  token "else", :Else

  regex("[0-9]+", :Number) do |lex|
    lex.extras.number_count += 1
    lex.extras.total_chars += lex.slice.size
  end

  skip_regex("\\s+", :Whitespace) do |lex|
    lex.extras.space_count += 1
    lex.extras.total_chars += lex.slice.size
  end

  regex("[a-zA-Z_][a-zA-Z0-9_]*", :Ident) do |lex|
    lex.extras.total_chars += lex.slice.size
  end

  error :Error
end

# Test 1: Callback modifies extras
lexer = Logos::Lexer(MyToken, String, MyExtras, Nil).new("if 123 else x", MyExtras.new)
tokens = [] of MyToken
lexer.each do |result|
  tokens << result.unwrap
end

puts "Tokens: #{tokens}"
puts "Extras: number_count=#{lexer.extras.number_count}, space_count=#{lexer.extras.space_count}, total_chars=#{lexer.extras.total_chars}"

if tokens == [MyToken::If, MyToken::Number, MyToken::Else, MyToken::Ident] &&
   lexer.extras.number_count == 1 &&
   lexer.extras.space_count == 3 && # spaces between tokens (3 spaces)
   lexer.extras.total_chars == 7    # "123"(3) + 3 spaces (3) + "x"(1) = 7 (only tokens with callbacks)
  puts "✓ Test 1 passed"
else
  puts "✗ Test 1 failed"
  exit 1
end

# Test 2: Error token (no callback)
lexer2 = Logos::Lexer(MyToken, String, MyExtras, Nil).new("@", MyExtras.new)
result2 = MyToken.lex(lexer2)
if result2 && result2.unwrap == MyToken::Error
  puts "✓ Test 2 passed (error token)"
else
  puts "✗ Test 2 failed"
  exit 1
end

puts "All callback tests passed!"
