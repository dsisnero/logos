require "../spec_helper"
require "regex-automata"

module Logos::Spec::Edgecase::MaybeTest
  Logos.define Token do
    regex("[0-9A-F][0-9A-F]a?", :Tok)
  end
end

module Logos::Spec::Edgecase::NumbersTest
  Logos.define Token do
    skip_token " ", :Space
    regex("[0-9][0-9_]*", :LiteralUnsignedNumber)
    regex("[0-9][0-9_]*\\.[0-9][0-9_]*[TGMKkmupfa]", :LiteralRealNumberDotScaleChar)
    regex("[0-9][0-9_]*\\.[0-9][0-9_]*[eE][+-]?[0-9][0-9_]*", :LiteralRealNumberDotExp)
    regex("[0-9][0-9_]*[TGMKkmupfa]", :LiteralRealNumberScaleChar)
    regex("[0-9][0-9_]*[eE][+-]?[0-9][0-9_]*", :LiteralRealNumberExp)
    regex("[0-9][0-9_]*\\.[0-9][0-9_]*", :LiteralRealNumberDot)
  end
end

describe "maybe_at_the_end" do
  it "matches F0 without optional a" do
    lexer = Logos::Lexer(Logos::Spec::Edgecase::MaybeTest::Token, String, Logos::NoExtras, Nil).new("F0")
    result = Logos::Spec::Edgecase::MaybeTest::Token.lex(lexer)
    result.should_not be_nil
    result = result.as(Logos::Result(Logos::Spec::Edgecase::MaybeTest::Token, Nil))
    result.unwrap.should eq(Logos::Spec::Edgecase::MaybeTest::Token::Tok)
    lexer.slice.should eq("F0")
    lexer.span.should eq(0...2)
  end

  it "matches F0a with optional a" do
    lexer = Logos::Lexer(Logos::Spec::Edgecase::MaybeTest::Token, String, Logos::NoExtras, Nil).new("F0a")
    result = Logos::Spec::Edgecase::MaybeTest::Token.lex(lexer)
    result.should_not be_nil
    result = result.as(Logos::Result(Logos::Spec::Edgecase::MaybeTest::Token, Nil))
    result.unwrap.should eq(Logos::Spec::Edgecase::MaybeTest::Token::Tok)
    lexer.slice.should eq("F0a")
    lexer.span.should eq(0...3)
  end
end

describe "numbers" do
  it "matches various number formats correctly" do
    source = "42.42 42 777777K 90e+8 42.42m 77.77e-29"
    lexer = Logos::Lexer(Logos::Spec::Edgecase::NumbersTest::Token, String, Logos::NoExtras, Nil).new(source)

    # Expected tokens in order
    expected = [
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberDot, "42.42", 0...5},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralUnsignedNumber, "42", 6...8},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberScaleChar, "777777K", 9...16},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberExp, "90e+8", 17...22},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberDotScaleChar, "42.42m", 23...29},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberDotExp, "77.77e-29", 30...39},
    ]

    expected.each do |expected_token, expected_slice, expected_range|
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(Logos::Spec::Edgecase::NumbersTest::Token, Nil))
      result.unwrap.should eq(expected_token)
      lexer.slice.should eq(expected_slice)
      lexer.span.should eq(expected_range)
    end

    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end
end
