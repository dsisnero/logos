# ASCII tokens lexer with custom error type.
#
# Usage:
#   crystal run examples/custom_error.cr

require "logos"

struct LexingError
  enum Kind
    InvalidInteger
    NonAsciiCharacter
    Other
  end

  getter kind : Kind
  getter detail : String

  def initialize(@kind : Kind = Kind::Other, @detail : String = "")
  end

  def self.invalid_integer(detail : String) : self
    new(Kind::InvalidInteger, detail)
  end

  def self.non_ascii(char : Char) : self
    new(Kind::NonAsciiCharacter, char.to_s)
  end

  def to_s(io : IO) : Nil
    case @kind
    when Kind::InvalidInteger
      io << "InvalidInteger(" << @detail << ")"
    when Kind::NonAsciiCharacter
      io << "NonAsciiCharacter(" << @detail << ")"
    else
      io << "Other"
    end
  end
end

Logos.define Token do
  error_type LexingError
  skip_regex "[ \t]+", :Whitespace

  regex "[a-zA-Z]+", :Word

  regex "[0-9]+", :Integer do |lex|
    begin
      value = lex.slice.to_u8
      Logos::Filter::Emit.new(value)
    rescue ex : ArgumentError
      Logos::FilterResult::Error.new(LexingError.invalid_integer("overflow error"))
    end
  end

  regex "[^\x00-\x7F]+", :NonAscii do |lex|
    char = lex.slice[0]
    Logos::FilterResult::Error.new(LexingError.non_ascii(char))
  end
end

lex = Token.lexer("Hello 256 Jérome")

while token = lex.next
  break if token.is_a?(Iterator::Stop)
  result = token.as(Logos::Result(Token, LexingError))
  if result.ok?
    case result.unwrap
    when Token::Word
      puts "Word: #{lex.slice}"
    when Token::Integer
      puts "Integer: #{lex.callback_value_as(UInt8)}"
    else
      # Skip
    end
  else
    puts "Error: #{result.unwrap_error} (slice=#{lex.slice})"
  end
end
