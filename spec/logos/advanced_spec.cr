require "../spec_helper"
require "regex-automata"

module Logos::Spec::Advanced
  Logos.define Token do
    error_type Nil

    subpattern :xdigit, "[0-9a-fA-F]"
    subpattern :a, "A"
    subpattern :b, "(?&a)BB(?&a)"

    skip_regex "[ \\t\\n\\f]+", :Whitespace

    regex %q("([^"\\]|\\t|\\u|\\n|\\")*"), :LiteralString
    regex "0[xX](?&xdigit)+", :LiteralHex
    regex "~?(?&b)~?", :Abba
    regex "-?[0-9]+", :LiteralInteger
    regex "[0-9]*\\.[0-9]+([eE][+-]?[0-9]+)?|[0-9]+[eE][+-]?[0-9]+", :LiteralFloat
    token "~", :LiteralNull
    token "~?", :Sgwt
    token "~%", :Sgcn
    token "~[", :Sglc
    regex "~[a-z][a-z]+", :LiteralUrbitAddress
    regex "~[0-9]+-?[\\.0-9a-f]+", :LiteralAbsDate
    regex "~s[0-9]+(\\.\\.[0-9a-f\\.]+)?", :LiteralRelDate
    regex "~[hm][0-9]+", :LiteralRelDate
    token "'", :SingleQuote
    token "'''", :TripleQuote
    regex "🦀+", :Rustaceans
    regex "[ąęśćżźńół]+", :Polish
    regex "[\\u0400-\\u04FF]+", :Cyrillic
    regex "([#@!\\?][#@!\\?][#@!\\?][#@!\\?])+", :WhatTheHeck
    regex "try|type|typeof", :Keyword
  end

  describe "subpatterns" do
    it "matches literal strings with escaped quotes" do
      source = %q( "" "foobar" "escaped\"quote" "escaped\nnew line" "\x" )
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::LiteralString), "\"\"", 1...3},
        {Logos::Result(Token, Nil).ok(Token::LiteralString), "\"foobar\"", 4...12},
        {Logos::Result(Token, Nil).ok(Token::LiteralString), "\"escaped\\\"quote\"", 13...29},
        {Logos::Result(Token, Nil).ok(Token::LiteralString), "\"escaped\\nnew line\"", 30...49},
        {Logos::Result(Token, Nil).error(nil), "\"", 50...51},
        {Logos::Result(Token, Nil).error(nil), "\\", 51...52},
        {Logos::Result(Token, Nil).error(nil), "x", 52...53},
        {Logos::Result(Token, Nil).error(nil), "\"", 53...54},
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

    it "matches hex literals with subpattern xdigit" do
      source = "0x 0X 0x0 0x9 0xa 0xf 0X0 0X9 0XA 0XF 0x123456789abcdefABCDEF 0xdeadBEEF"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::LiteralInteger), "0", 0...1},
        {Logos::Result(Token, Nil).error(nil), "x", 1...2},
        {Logos::Result(Token, Nil).ok(Token::LiteralInteger), "0", 3...4},
        {Logos::Result(Token, Nil).error(nil), "X", 4...5},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0x0", 6...9},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0x9", 10...13},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0xa", 14...17},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0xf", 18...21},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0X0", 22...25},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0X9", 26...29},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0XA", 30...33},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0XF", 34...37},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0x123456789abcdefABCDEF", 38...61},
        {Logos::Result(Token, Nil).ok(Token::LiteralHex), "0xdeadBEEF", 62...72},
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

    it "matches ABBA pattern with subpatterns a and b" do
      source = "ABBA~ ~ABBA ~ABBA~ ABBA"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::Abba), "ABBA~", 0...5},
        {Logos::Result(Token, Nil).ok(Token::Abba), "~ABBA", 6...11},
        {Logos::Result(Token, Nil).ok(Token::Abba), "~ABBA~", 12...18},
        {Logos::Result(Token, Nil).ok(Token::Abba), "ABBA", 19...23},
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

    it "matches integers" do
      source = "0 5 123 9001 -42"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::LiteralInteger), "0", 0...1},
        {Logos::Result(Token, Nil).ok(Token::LiteralInteger), "5", 2...3},
        {Logos::Result(Token, Nil).ok(Token::LiteralInteger), "123", 4...7},
        {Logos::Result(Token, Nil).ok(Token::LiteralInteger), "9001", 8...12},
        {Logos::Result(Token, Nil).ok(Token::LiteralInteger), "-42", 13...16},
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

    it "matches floats" do
      source = "0.0 3.14 .1234 10e5 5E-10 42.9001e+12 .1e-3"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::LiteralFloat), "0.0", 0...3},
        {Logos::Result(Token, Nil).ok(Token::LiteralFloat), "3.14", 4...8},
        {Logos::Result(Token, Nil).ok(Token::LiteralFloat), ".1234", 9...14},
        {Logos::Result(Token, Nil).ok(Token::LiteralFloat), "10e5", 15...19},
        {Logos::Result(Token, Nil).ok(Token::LiteralFloat), "5E-10", 20...25},
        {Logos::Result(Token, Nil).ok(Token::LiteralFloat), "42.9001e+12", 26...37},
        {Logos::Result(Token, Nil).ok(Token::LiteralFloat), ".1e-3", 38...43},
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

    it "matches literal null and sigils" do
      source = "~ ~? ~% ~["
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::LiteralNull), "~", 0...1},
        {Logos::Result(Token, Nil).ok(Token::Sgwt), "~?", 2...4},
        {Logos::Result(Token, Nil).ok(Token::Sgcn), "~%", 5...7},
        {Logos::Result(Token, Nil).ok(Token::Sglc), "~[", 8...10},
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

    it "matches Urbit addresses and dates" do
      source = "~ab ~2024 ~2024.2a ~s123 ~s123..4f.0a ~h7 ~m9"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::LiteralUrbitAddress), "~ab", 0...3},
        {Logos::Result(Token, Nil).ok(Token::LiteralAbsDate), "~2024", 4...9},
        {Logos::Result(Token, Nil).ok(Token::LiteralAbsDate), "~2024.2a", 10...18},
        {Logos::Result(Token, Nil).ok(Token::LiteralRelDate), "~s123", 19...24},
        {Logos::Result(Token, Nil).ok(Token::LiteralRelDate), "~s123..4f.0a", 25...37},
        {Logos::Result(Token, Nil).ok(Token::LiteralRelDate), "~h7", 38...41},
        {Logos::Result(Token, Nil).ok(Token::LiteralRelDate), "~m9", 42...45},
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

    it "matches single and triple quotes" do
      source = "' ''' '"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::SingleQuote), "'", 0...1},
        {Logos::Result(Token, Nil).ok(Token::TripleQuote), "'''", 2...5},
        {Logos::Result(Token, Nil).ok(Token::SingleQuote), "'", 6...7},
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

    it "matches Rustaceans" do
      source = "🦀 🦀🦀 🦀🦀🦀 🦀🦀🦀🦀"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::Rustaceans), "🦀", 0...4},
        {Logos::Result(Token, Nil).ok(Token::Rustaceans), "🦀🦀", 5...13},
        {Logos::Result(Token, Nil).ok(Token::Rustaceans), "🦀🦀🦀", 14...26},
        {Logos::Result(Token, Nil).ok(Token::Rustaceans), "🦀🦀🦀🦀", 27...43},
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

    it "matches Polish and Cyrillic" do
      source = "ą ę ó ąąąą łóżź привет"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::Polish), "ą", 0...2},
        {Logos::Result(Token, Nil).ok(Token::Polish), "ę", 3...5},
        {Logos::Result(Token, Nil).ok(Token::Polish), "ó", 6...8},
        {Logos::Result(Token, Nil).ok(Token::Polish), "ąąąą", 9...17},
        {Logos::Result(Token, Nil).ok(Token::Polish), "łóżź", 18...26},
        {Logos::Result(Token, Nil).ok(Token::Cyrillic), "привет", 27...39},
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

    it "matches the what the heck pattern" do
      source = "!#@? #!!!?!@? ????####@@@@!!!!"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::WhatTheHeck), "!#@?", 0...4},
        {Logos::Result(Token, Nil).ok(Token::WhatTheHeck), "#!!!?!@?", 5...13},
        {Logos::Result(Token, Nil).ok(Token::WhatTheHeck), "????####@@@@!!!!", 14...30},
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

    it "matches keywords" do
      source = "try type typeof"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Result(Token, Nil).ok(Token::Keyword), "try", 0...3},
        {Logos::Result(Token, Nil).ok(Token::Keyword), "type", 4...8},
        {Logos::Result(Token, Nil).ok(Token::Keyword), "typeof", 9...15},
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
end
