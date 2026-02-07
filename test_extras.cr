require "./src/logos"

# Define a custom extras type
class MyExtras
  property count : Int32

  def initialize
    @count = 0
  end
end

# Define a custom error type
alias MyError = String

# Define token enum with extras and error_type
Logos.define MyToken do
  extras MyExtras
  error_type MyError

  token "if", :If
  token "else", :Else
  regex "[a-zA-Z_][a-zA-Z0-9_]*", :Ident
  skip_regex "\\s+", :Ws
  error :Err
end

puts "MyToken defined successfully"
puts "MyToken::If = #{MyToken::If}"

# Test that lex method has correct signature
# (compile-time check)
lexer = Logos::Lexer(MyToken, String, MyExtras, MyError).new("if x", MyExtras.new)
result = MyToken.lex(lexer)
puts "First token: #{result}"
if result
  puts "Token: #{result.unwrap}"
  puts "Slice: #{lexer.slice}"
end

# Test error type
lexer2 = Logos::Lexer(MyToken, String, MyExtras, MyError).new("@", MyExtras.new)
result2 = MyToken.lex(lexer2)
puts "Error token: #{result2}"
if result2
  puts "Token: #{result2.unwrap}"
  # This should be Err variant
end

puts "Test passed!"
