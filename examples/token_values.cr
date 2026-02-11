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
lexer = Token.lexer(source)

puts "Tokenizing: #{source}"
puts ""

while result = lexer.next
  break if result.is_a?(Iterator::Stop)

  if result.ok?
    token = result.unwrap
    case token
    when Token::Integer
      puts "Integer: #{lexer.int_value}"
    when Token::Float
      puts "Float: #{lexer.float_value}"
    when Token::String
      puts "String: #{lexer.string_value}"
    when Token::Plus
      puts "Plus"
    end

    # Clear callback value for next token
    lexer.clear_callback_value
  end
end

puts ""
puts "Alternative pattern using callback_value directly:"
lexer = Token.lexer(source)
lexer.each do |res|
  if res.ok?
    token = res.unwrap
    value = lexer.callback_value

    puts "#{token}: #{value.inspect}"
    lexer.clear_callback_value
  end
end
