require "../spec_helper"
require "regex-automata"

module Logos::Spec::Simple
  # Mock extras class similar to Rust version (needs to be reference type for mutation)
  class MockExtras
    property spaces : Int32
    property line_breaks : Int32
    property numbers : Int32
    property byte_size : UInt8

    def initialize
      @spaces = 0
      @line_breaks = 0
      @numbers = 0
      @byte_size = 0
    end
  end

  # Callback functions (need to be defined before Token enum)
  def self.byte_size_2(lexer : Logos::Lexer(Token, String, MockExtras, Nil))
    lexer.extras.byte_size = 2_u8
  end

  def self.byte_size_4(lexer : Logos::Lexer(Token, String, MockExtras, Nil))
    lexer.extras.byte_size = 4_u8
  end

  # Define token enum with extras and callbacks
  Logos.define Token do
    extras MockExtras
    error_type Nil

    # Skip patterns attached to Identifier variant
    token "\n", :Identifier do |lex|
      lex.extras.line_breaks += 1
      Logos::Skip.new
    end

    regex "[ \\t\\f]", :Identifier do |lex|
      lex.extras.spaces += 1
      Logos::Skip.new
    end

    # Actual identifier pattern (no callback, emits Identifier)
    regex "[a-zA-Z$_][a-zA-Z0-9$_]*", :Identifier

    # Number with callback
    regex "[1-9][0-9]*|0", :Number do |lex|
      lex.extras.numbers += 1
    end

    # Binary literal
    regex "0b[01]+", :Binary

    # Hex literal
    regex "0x[0-9a-fA-F]+", :Hex

    # Complex regex with alternation
    regex "(abc)+(def|xyz)?", :Abc

    # Keywords
    token "priv", :Priv
    token "private", :Private
    token "primitive", :Primitive
    token "protected", :Protected
    token "protectee", :Protectee
    token "in", :In
    token "instanceof", :Instanceof

    # Byte types
    regex "byte|bytes[1-9][0-9]?", :Byte

    # Int types with complex regex
    regex "int(8|16|24|32|40|48|56|64|72|80|88|96|104|112|120|128|136|144|152|160|168|176|184|192|200|208|216|224|232|240|248|256)", :Int

    # Uint types with callbacks
    token "uint8", :Uint do |lex|
      lex.extras.byte_size = 1_u8
    end

    # Need to use method references for uint16 and uint32
    # For now, use inline blocks
    token "uint16", :Uint do |lex|
      lex.extras.byte_size = 2_u8
    end

    token "uint32", :Uint do |lex|
      lex.extras.byte_size = 4_u8
    end

    # Punctuation
    token ".", :Accessor
    token "...", :Ellipsis
    token "{", :BraceOpen
    token "}", :BraceClose
    token "+", :OpAddition
    token "++", :OpIncrement
    token "=", :OpAssign
    token "==", :OpEquality
    token "===", :OpStrictEquality
    token "=>", :FatArrow
  end
end

describe "simple.rs tests" do
  describe "empty" do
    it "returns no tokens for empty source" do
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new("")
      lexer.next.should eq(Iterator::Stop::INSTANCE)
      lexer.span.should eq(0...0)
    end
  end

  describe "whitespace" do
    it "skips whitespace and returns no tokens" do
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new("     ")
      lexer.next.should eq(Iterator::Stop::INSTANCE)
      lexer.span.should eq(5...5)
    end
  end

  describe "operators" do
    it "matches operators correctly" do
      source = "=== == = => + ++"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::OpStrictEquality, "===", 0...3},
        {Logos::Spec::Simple::Token::OpEquality, "==", 4...6},
        {Logos::Spec::Simple::Token::OpAssign, "=", 7...8},
        {Logos::Spec::Simple::Token::FatArrow, "=>", 9...11},
        {Logos::Spec::Simple::Token::OpAddition, "+", 12...13},
        {Logos::Spec::Simple::Token::OpIncrement, "++", 14...16},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "punctuation" do
    it "matches punctuation correctly" do
      source = "{ . .. ... }"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::BraceOpen, "{", 0...1},
        {Logos::Spec::Simple::Token::Accessor, ".", 2...3},
        {Logos::Spec::Simple::Token::Accessor, ".", 4...5},
        {Logos::Spec::Simple::Token::Accessor, ".", 5...6},
        {Logos::Spec::Simple::Token::Ellipsis, "...", 7...10},
        {Logos::Spec::Simple::Token::BraceClose, "}", 11...12},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "identifiers" do
    it "matches identifiers correctly" do
      source = "It was the year when they finally immanentized the Eschaton."
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Identifier, "It", 0...2},
        {Logos::Spec::Simple::Token::Identifier, "was", 3...6},
        {Logos::Spec::Simple::Token::Identifier, "the", 7...10},
        {Logos::Spec::Simple::Token::Identifier, "year", 11...15},
        {Logos::Spec::Simple::Token::Identifier, "when", 16...20},
        {Logos::Spec::Simple::Token::Identifier, "they", 21...25},
        {Logos::Spec::Simple::Token::Identifier, "finally", 26...33},
        {Logos::Spec::Simple::Token::Identifier, "immanentized", 34...46},
        {Logos::Spec::Simple::Token::Identifier, "the", 47...50},
        {Logos::Spec::Simple::Token::Identifier, "Eschaton", 51...59},
        {Logos::Spec::Simple::Token::Accessor, ".", 59...60},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "keywords" do
    it "matches keywords correctly" do
      source = "priv private primitive protected protectee in instanceof"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Priv, "priv", 0...4},
        {Logos::Spec::Simple::Token::Private, "private", 5...12},
        {Logos::Spec::Simple::Token::Primitive, "primitive", 13...22},
        {Logos::Spec::Simple::Token::Protected, "protected", 23...32},
        {Logos::Spec::Simple::Token::Protectee, "protectee", 33...42},
        {Logos::Spec::Simple::Token::In, "in", 43...45},
        {Logos::Spec::Simple::Token::Instanceof, "instanceof", 46...56},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "keywords_mix_identifiers" do
    it "distinguishes keywords from similar identifiers" do
      source = "pri priv priva privb privat private privatee privateer"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Identifier, "pri", 0...3},
        {Logos::Spec::Simple::Token::Priv, "priv", 4...8},
        {Logos::Spec::Simple::Token::Identifier, "priva", 9...14},
        {Logos::Spec::Simple::Token::Identifier, "privb", 15...20},
        {Logos::Spec::Simple::Token::Identifier, "privat", 21...27},
        {Logos::Spec::Simple::Token::Private, "private", 28...35},
        {Logos::Spec::Simple::Token::Identifier, "privatee", 36...44},
        {Logos::Spec::Simple::Token::Identifier, "privateer", 45...54},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "iterator" do
    it "collects tokens via iterator" do
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new("pri priv priva private")
      tokens = [] of Logos::Spec::Simple::Token

      lexer.each do |result|
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        tokens << result.unwrap
      end

      tokens.should eq([
        Logos::Spec::Simple::Token::Identifier,
        Logos::Spec::Simple::Token::Priv,
        Logos::Spec::Simple::Token::Identifier,
        Logos::Spec::Simple::Token::Private,
      ])
    end
  end

  describe "spanned_iterator" do
    it "collects tokens with spans via spanned iterator" do
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new("pri priv priva private")
      spanned_tokens = [] of {Logos::Result(Logos::Spec::Simple::Token, Nil), Range(Int32, Int32)}

      lexer.spanned.each do |result, span|
        spanned_tokens << {result.as(Logos::Result(Logos::Spec::Simple::Token, Nil)), span}
      end

      spanned_tokens.should eq([
        {Logos::Result(Logos::Spec::Simple::Token, Nil).ok(Logos::Spec::Simple::Token::Identifier), 0...3},
        {Logos::Result(Logos::Spec::Simple::Token, Nil).ok(Logos::Spec::Simple::Token::Priv), 4...8},
        {Logos::Result(Logos::Spec::Simple::Token, Nil).ok(Logos::Spec::Simple::Token::Identifier), 9...14},
        {Logos::Result(Logos::Spec::Simple::Token, Nil).ok(Logos::Spec::Simple::Token::Private), 15...22},
      ])
    end
  end

  describe "numbers" do
    it "matches numbers correctly" do
      source = "0 1 2 3 4 10 42 1337"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Number, "0", 0...1},
        {Logos::Spec::Simple::Token::Number, "1", 2...3},
        {Logos::Spec::Simple::Token::Number, "2", 4...5},
        {Logos::Spec::Simple::Token::Number, "3", 6...7},
        {Logos::Spec::Simple::Token::Number, "4", 8...9},
        {Logos::Spec::Simple::Token::Number, "10", 10...12},
        {Logos::Spec::Simple::Token::Number, "42", 13...15},
        {Logos::Spec::Simple::Token::Number, "1337", 16...20},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
      # Verify extras.numbers was incremented (8 numbers)
      lexer.extras.numbers.should eq(8)
    end
  end

  describe "invalid_tokens" do
    it "produces errors for invalid tokens" do
      source = "@-/!"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Result(Logos::Spec::Simple::Token, Nil).error(nil), "@", 0...1},
        {Logos::Result(Logos::Spec::Simple::Token, Nil).error(nil), "-", 1...2},
        {Logos::Result(Logos::Spec::Simple::Token, Nil).error(nil), "/", 2...3},
        {Logos::Result(Logos::Spec::Simple::Token, Nil).error(nil), "!", 3...4},
      ]

      expected.each do |expected_result, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result.should eq(expected_result)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "hex_and_binary" do
    it "matches hex and binary literals" do
      source = "0x0672deadbeef 0b0100010011"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Hex, "0x0672deadbeef", 0...14},
        {Logos::Spec::Simple::Token::Binary, "0b0100010011", 15...27},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "invalid_hex_and_binary" do
    it "tokenizes incomplete hex/binary as number and identifier" do
      source = "0x 0b"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Number, "0", 0...1},
        {Logos::Spec::Simple::Token::Identifier, "x", 1...2},
        {Logos::Spec::Simple::Token::Number, "0", 3...4},
        {Logos::Spec::Simple::Token::Identifier, "b", 4...5},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "abcs" do
    it "matches abc patterns" do
      source = "abc abcabcabcabc abcdef abcabcxyz"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Abc, "abc", 0...3},
        {Logos::Spec::Simple::Token::Abc, "abcabcabcabc", 4...16},
        {Logos::Spec::Simple::Token::Abc, "abcdef", 17...23},
        {Logos::Spec::Simple::Token::Abc, "abcabcxyz", 24...33},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "invalid_abcs" do
    it "matches invalid abc patterns as identifiers" do
      source = "ab abca abcabcab abxyz abcxy abcdefxyz"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Identifier, "ab", 0...2},
        {Logos::Spec::Simple::Token::Identifier, "abca", 3...7},
        {Logos::Spec::Simple::Token::Identifier, "abcabcab", 8...16},
        {Logos::Spec::Simple::Token::Identifier, "abxyz", 17...22},
        {Logos::Spec::Simple::Token::Identifier, "abcxy", 23...28},
        {Logos::Spec::Simple::Token::Identifier, "abcdefxyz", 29...38},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "bytes" do
    it "matches byte patterns" do
      source = "byte bytes1 bytes32"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Byte, "byte", 0...4},
        {Logos::Spec::Simple::Token::Byte, "bytes1", 5...11},
        {Logos::Spec::Simple::Token::Byte, "bytes32", 12...19},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "extras_and_callbacks" do
    it "updates extras via callbacks" do
      source = "foo  bar     \n 42\n     HAL=9000"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      # Lex all tokens
      while lexer.next.is_a?(Logos::Result)
      end

      # Check extras (new-lines still count as trivia here)
      lexer.extras.spaces.should eq(13)
      lexer.extras.line_breaks.should eq(2)
      lexer.extras.numbers.should eq(2)
    end
  end

  describe "ints" do
    it "matches int patterns" do
      source = "int8 int16 int24 int32 int40 int48 int56 int64 int72 int80 " \
               "int88 int96 int104 int112 int120 int128 int136 int144 int152 " \
               "int160 int168 int176 int184 int192 int200 int208 int216 int224 " \
               "int232 int240 int248 int256"
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Simple::Token::Int, "int8", 0...4},
        {Logos::Spec::Simple::Token::Int, "int16", 5...10},
        {Logos::Spec::Simple::Token::Int, "int24", 11...16},
        {Logos::Spec::Simple::Token::Int, "int32", 17...22},
        {Logos::Spec::Simple::Token::Int, "int40", 23...28},
        {Logos::Spec::Simple::Token::Int, "int48", 29...34},
        {Logos::Spec::Simple::Token::Int, "int56", 35...40},
        {Logos::Spec::Simple::Token::Int, "int64", 41...46},
        {Logos::Spec::Simple::Token::Int, "int72", 47...52},
        {Logos::Spec::Simple::Token::Int, "int80", 53...58},
        {Logos::Spec::Simple::Token::Int, "int88", 59...64},
        {Logos::Spec::Simple::Token::Int, "int96", 65...70},
        {Logos::Spec::Simple::Token::Int, "int104", 71...77},
        {Logos::Spec::Simple::Token::Int, "int112", 78...84},
        {Logos::Spec::Simple::Token::Int, "int120", 85...91},
        {Logos::Spec::Simple::Token::Int, "int128", 92...98},
        {Logos::Spec::Simple::Token::Int, "int136", 99...105},
        {Logos::Spec::Simple::Token::Int, "int144", 106...112},
        {Logos::Spec::Simple::Token::Int, "int152", 113...119},
        {Logos::Spec::Simple::Token::Int, "int160", 120...126},
        {Logos::Spec::Simple::Token::Int, "int168", 127...133},
        {Logos::Spec::Simple::Token::Int, "int176", 134...140},
        {Logos::Spec::Simple::Token::Int, "int184", 141...147},
        {Logos::Spec::Simple::Token::Int, "int192", 148...154},
        {Logos::Spec::Simple::Token::Int, "int200", 155...161},
        {Logos::Spec::Simple::Token::Int, "int208", 162...168},
        {Logos::Spec::Simple::Token::Int, "int216", 169...175},
        {Logos::Spec::Simple::Token::Int, "int224", 176...182},
        {Logos::Spec::Simple::Token::Int, "int232", 183...189},
        {Logos::Spec::Simple::Token::Int, "int240", 190...196},
        {Logos::Spec::Simple::Token::Int, "int248", 197...203},
        {Logos::Spec::Simple::Token::Int, "int256", 204...210},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "uints" do
    it "matches uint patterns with callbacks setting byte_size" do
      lexer = Logos::Lexer(Logos::Spec::Simple::Token, String, Logos::Spec::Simple::MockExtras, Nil).new("uint8 uint16 uint32")

      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
      result.unwrap.should eq(Logos::Spec::Simple::Token::Uint)
      lexer.span.should eq(0...5)
      lexer.extras.byte_size.should eq(1)

      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
      result.unwrap.should eq(Logos::Spec::Simple::Token::Uint)
      lexer.span.should eq(6...12)
      lexer.extras.byte_size.should eq(2)

      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(Logos::Spec::Simple::Token, Nil))
      result.unwrap.should eq(Logos::Spec::Simple::Token::Uint)
      lexer.span.should eq(13...19)
      lexer.extras.byte_size.should eq(4)

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
