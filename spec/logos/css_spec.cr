require "../spec_helper"
require "regex-automata"

module Logos::Spec::Css
  Logos.define Token do
    skip_regex "[ \\t\\n\\f]+", :Whitespace
    regex "em|ex|ch|rem|vw|vh|vmin|vmax", :RelativeLength
    regex "cm|mm|Q|in|pc|pt|px", :AbsoluteLength, priority: 3
    regex "[+-]?[0-9]*[.]?[0-9]+(?:[eE][+-]?[0-9]+)?", :Number, priority: 3
    regex "[-a-zA-Z_][a-zA-Z0-9_-]*", :Ident
    token "{", :CurlyBracketOpen
    token "}", :CurlyBracketClose
    token ":", :Colon
  end
end

describe "css.rs tests" do
  describe "test_line_height" do
    it "tokenizes line-height with absolute length" do
      source = "h2 { line-height: 3cm }"
      lexer = Logos::Lexer(Logos::Spec::Css::Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Css::Token::Ident, "h2", 0...2},
        {Logos::Spec::Css::Token::CurlyBracketOpen, "{", 3...4},
        {Logos::Spec::Css::Token::Ident, "line-height", 5...16},
        {Logos::Spec::Css::Token::Colon, ":", 16...17},
        {Logos::Spec::Css::Token::Number, "3", 18...19},
        {Logos::Spec::Css::Token::AbsoluteLength, "cm", 19...21},
        {Logos::Spec::Css::Token::CurlyBracketClose, "}", 22...23},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Css::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "test_word_spacing" do
    it "tokenizes word-spacing with absolute length" do
      source = "h3 { word-spacing: 4mm }"
      lexer = Logos::Lexer(Logos::Spec::Css::Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Css::Token::Ident, "h3", 0...2},
        {Logos::Spec::Css::Token::CurlyBracketOpen, "{", 3...4},
        {Logos::Spec::Css::Token::Ident, "word-spacing", 5...17},
        {Logos::Spec::Css::Token::Colon, ":", 17...18},
        {Logos::Spec::Css::Token::Number, "4", 19...20},
        {Logos::Spec::Css::Token::AbsoluteLength, "mm", 20...22},
        {Logos::Spec::Css::Token::CurlyBracketClose, "}", 23...24},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Css::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "test_letter_spacing" do
    it "tokenizes letter-spacing with relative length" do
      source = "h3 { letter-spacing: 42em }"
      lexer = Logos::Lexer(Logos::Spec::Css::Token, String, Logos::NoExtras, Nil).new(source)

      expected = [
        {Logos::Spec::Css::Token::Ident, "h3", 0...2},
        {Logos::Spec::Css::Token::CurlyBracketOpen, "{", 3...4},
        {Logos::Spec::Css::Token::Ident, "letter-spacing", 5...19},
        {Logos::Spec::Css::Token::Colon, ":", 19...20},
        {Logos::Spec::Css::Token::Number, "42", 21...23},
        {Logos::Spec::Css::Token::RelativeLength, "em", 23...25},
        {Logos::Spec::Css::Token::CurlyBracketClose, "}", 26...27},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Logos::Spec::Css::Token, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
