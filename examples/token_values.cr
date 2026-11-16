require "../src/logos"

# Example of token variants with associated data using callbacks
Logos.define Token do
  # Integer token with value
  regex "[0-9]+", :Integer do |lexer|
    Logos::Filter::Emit.new(lexer.slice.to_i64)
  end

  # Float token with value
  regex "[0-9]+\\.[0-9]+", :Float do |lexer|
    Logos::Filter::Emit.new(lexer.slice.to_f64)
  end

  # String literal token with value (without quotes)
  regex "\"[^\"]*\"", :String do |lexer|
    Logos::Filter::Emit.new(lexer.slice[1...-1])
  end

  # Simple token without value
  token "+", :Plus

  # Skip whitespace
  skip_regex "[ \t\n]+", :Whitespace
end

source = "123 + 45.67 \"hello\""
results = Token.lex_all(source)

puts "Tokenizing: #{source}"
puts ""

results.each do |result|
  case result.unwrap
  when Token::Integer
    puts "Integer: #{result.payload_for!(Token::Integer, Int64)}"
  when Token::Float
    puts "Float: #{result.payload_for!(Token::Float, Float64)}"
  when Token::String
    puts "String: #{result.payload_for!(Token::String, String)}"
  when Token::Plus
    puts "Plus"
  end
end
