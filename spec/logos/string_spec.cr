require "../spec_helper"
require "regex-automata"

module Logos::Spec::StringTests
  def self.hex_value(byte : UInt8?) : Int32?
    return unless byte
    case byte
    when 0x30..0x39 then (byte - 0x30).to_i
    when 0x41..0x46 then (byte - 0x41 + 10).to_i
    when 0x61..0x66 then (byte - 0x61 + 10).to_i
    end
  end

  def self.simple_escape(esc : UInt8) : Char?
    case esc
    when 'n'.ord  then '\n'
    when 'r'.ord  then '\r'
    when 't'.ord  then '\t'
    when '0'.ord  then '\u{0}'
    when '\''.ord then '\''
    when '"'.ord  then '"'
    when '\\'.ord then '\\'
    end
  end

  def self.append_hex_escape(bytes : Bytes, i : Int32, builder : String::Builder) : Int32
    hi = hex_value(bytes[i + 1]?)
    lo = hex_value(bytes[i + 2]?)
    if hi && lo
      builder << (hi * 16 + lo).chr
      return i + 2
    end
    i
  end

  def self.append_unicode_escape(bytes : Bytes, i : Int32, builder : String::Builder) : Int32
    return i unless bytes[i + 1]? == '{'.ord

    j = i + 2
    start = j
    while j < bytes.size && bytes[j] != '}'.ord
      j += 1
    end
    return i unless j < bytes.size

    codepoint = String.new(bytes[start, j - start]).to_i(16)
    builder << codepoint.chr
    j
  end

  def self.append_escape(bytes : Bytes, i : Int32, builder : String::Builder) : Int32
    esc = bytes[i]?
    return i unless esc

    if esc == 'x'.ord
      return append_hex_escape(bytes, i, builder)
    end

    if esc == 'u'.ord
      return append_unicode_escape(bytes, i, builder)
    end

    if char = simple_escape(esc)
      builder << char
      return i
    end

    builder << esc.chr
    i
  end

  def self.lex_single_line_string(lex : Logos::Lexer(Token, String, Logos::NoExtras, Nil)) : Logos::Filter::Emit(String)
    slice = lex.slice
    inner = slice[1, slice.size - 2]
    bytes = inner.to_slice
    builder = String::Builder.new
    i = 0
    while i < bytes.size
      byte = bytes[i]
      if byte == '\\'.ord
        i += 1
        break if i >= bytes.size
        i = append_escape(bytes, i, builder)
      else
        builder << byte.chr
      end
      i += 1
    end
    Logos::Filter::Emit.new(builder.to_s)
  end

  Logos.define Token do
    error_type Nil

    regex "[ \\t\\n\\r]+", :Whitespace do
      Logos::Skip.new
    end

    regex "\"([^\"\\\\]+|\\\\.)*\"", :String do |lex|
      Logos::Spec::StringTests.lex_single_line_string(lex)
    end
  end

  describe "token variants with associated data" do
    it "parses string literals with escape sequences" do
      source = %q("line\nend" "\x41" "\u{5A}" "\"quoted\"")
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::String)
      lexer.callback_value_as(String).should eq("line\nend")

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::String)
      lexer.callback_value_as(String).should eq("A")

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::String)
      lexer.callback_value_as(String).should eq("Z")

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::String)
      lexer.callback_value_as(String).should eq("\"quoted\"")

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end

    it "works without cloning lexer" do
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(%q("a" "b"))

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::String)
      lexer.callback_value_as(String).should eq("a")

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::String)
      lexer.callback_value_as(String).should eq("b")
    end

    it "works with cloning lexer" do
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(%q("a" "b"))

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::String)
      lexer.callback_value_as(String).should eq("a")

      cloned = lexer.clone
      result = cloned.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::String)
      cloned.callback_value_as(String).should eq("b")

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::String)
      lexer.callback_value_as(String).should eq("b")
    end
  end
end
