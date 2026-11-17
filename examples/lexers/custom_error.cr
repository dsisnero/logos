require "../../src/logos"

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

  regex "[^\x00-\x7F]", :NonAscii do |lex|
    char = lex.slice[0]
    Logos::FilterResult::Error.new(LexingError.non_ascii(char))
  end
end
