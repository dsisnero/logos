require "../spec_helper"
require "regex-automata"

module Logos::Spec::StringTests
  def self.read_hex(chars : Iterator(Char), width : Int32, stop_at_brace = false) : UInt32?
    digits = String.build do |output|
      width.times do
        char = chars.next
        return unless char.is_a?(Char)
        break if stop_at_brace && char == '}'
        output << char
      end
    end
    return if digits.starts_with?('-')
    digits.to_u32?(16, whitespace: false)
  end

  def self.decode_escape(escape : Char, chars : Iterator(Char)) : Char?
    case escape
    when 'n' then '\n'
    when 'r' then '\r'
    when 't' then '\t'
    when '0' then '\0'
    when '\'', '"', '\\'
      escape
    when 'x'
      if (codepoint = read_hex(chars, 2)) && codepoint <= 0x7F
        codepoint.chr
      end
    when 'u'
      return unless chars.next == '{'
      if (codepoint = read_hex(chars, 6, stop_at_brace: true)) &&
         codepoint <= Char::MAX_CODEPOINT && !(0xD800..0xDFFF).includes?(codepoint)
        codepoint.chr
      end
    end
  end

  def self.lex_single_line_string(lex : Logos::Lexer(Token, String, Logos::NoExtras, Nil)) : Logos::FilterResult::Emit(String) | Logos::FilterResult::Error(Nil)
    slice = lex.slice
    chars = slice.byte_slice(1, slice.bytesize - 2).each_char
    payload = String.build do |output|
      loop do
        char = chars.next
        break unless char.is_a?(Char)

        if char == '\\'
          escape = chars.next
          return Logos::FilterResult::Error.new(nil) unless escape.is_a?(Char)
          next if escape == '\n'
          char = decode_escape(escape, chars)
          return Logos::FilterResult::Error.new(nil) unless char
        end
        output << char
      end
    end
    Logos::FilterResult::Emit.new(payload)
  end

  Logos.define Token do
    error_type Nil
    skip_token " ", :Whitespace

    regex "\"([^\"\\\\]+|\\\\.)*\"", :String do |lex|
      Logos::Spec::StringTests.lex_single_line_string(lex)
    end
  end

  UPSTREAM_SOURCE = %q("Hello, world!" "foo😀bar\nbaz \x3F\u{1234}")
  SECOND_LEXEME   = %q("foo😀bar\nbaz \x3F\u{1234}")
  SECOND_PAYLOAD  = "foo😀bar\nbaz ?\u{1234}"

  def self.assert_string(lexer, payload : String, lexeme : String, span : Logos::Span) : Logos::Result(Token, Nil)
    result, actual_span = lexer.spanned.next.as({Logos::Result(Token, Nil), Logos::Span})
    result.payload_for!(Token::String, String).should eq(payload)
    lexer.slice.should eq(lexeme)
    actual_span.should eq(span)
    result
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

    it "reports malformed escapes over the entire matched lexeme and resumes" do
      lexer = Token.lexer(%q("\q" "\x80" "\xG1" "\u{D800}" "\u{110000}" "end"))
      stream = lexer.spanned
      [
        { %q("\q"), 0...4 },
        { %q("\x80"), 5...11 },
        { %q("\xG1"), 12...18 },
        { %q("\u{D800}"), 19...29 },
        { %q("\u{110000}"), 30...42 },
      ].each do |lexeme, span|
        stream.next.should eq({Logos::Result(Token, Nil).error(nil), span})
        lexer.slice.should eq(lexeme)
      end
      Logos::Spec::StringTests.assert_string(lexer, "end", %q("end"), 43...48)
      stream.next.should eq(Iterator::Stop::INSTANCE)
    end

    it "decodes the exact upstream string stream" do
      lexer = Token.lexer(UPSTREAM_SOURCE)
      first = Logos::Spec::StringTests.assert_string(lexer, "Hello, world!", %q("Hello, world!"), 0...15)
      Logos::Spec::StringTests.assert_string(lexer, SECOND_PAYLOAD, SECOND_LEXEME, 16...46)
      lexer.next.should eq(Iterator::Stop::INSTANCE)
      first.payload_for!(Token::String, String).should eq("Hello, world!")
    end

    it "keeps the upstream clone cursors and string payloads independent" do
      original = Token.lexer(UPSTREAM_SOURCE)
      second = original.clone
      Logos::Spec::StringTests.assert_string(second, "Hello, world!", %q("Hello, world!"), 0...15)
      third = second.clone
      fourth = third.clone
      Logos::Spec::StringTests.assert_string(third, SECOND_PAYLOAD, SECOND_LEXEME, 16...46)
      Logos::Spec::StringTests.assert_string(fourth, SECOND_PAYLOAD, SECOND_LEXEME, 16...46)
      fourth.next.should eq(Iterator::Stop::INSTANCE)

      fifth = original.clone
      Logos::Spec::StringTests.assert_string(fifth, "Hello, world!", %q("Hello, world!"), 0...15)
      Logos::Spec::StringTests.assert_string(fifth, SECOND_PAYLOAD, SECOND_LEXEME, 16...46)
      Logos::Spec::StringTests.assert_string(original, "Hello, world!", %q("Hello, world!"), 0...15)
      fifth.next.should eq(Iterator::Stop::INSTANCE)
      Logos::Spec::StringTests.assert_string(second, SECOND_PAYLOAD, SECOND_LEXEME, 16...46)
      second.next.should eq(Iterator::Stop::INSTANCE)
      third.next.should eq(Iterator::Stop::INSTANCE)
      Logos::Spec::StringTests.assert_string(original, SECOND_PAYLOAD, SECOND_LEXEME, 16...46)
      original.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
