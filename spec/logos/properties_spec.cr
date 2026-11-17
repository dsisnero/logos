require "../spec_helper"
require "regex-automata"

module Logos::Spec::Properties
  Logos.define ScriptToken do
    skip_regex "[ \\t\\n\\f]+", :Whitespace
    regex "[a-zA-Z]+", :Ascii
    regex %q(\p{Greek}+), :Greek
    regex %q(\p{Cyrillic}+), :Cyrillic
  end

  module LatinTest
    Logos.define Token do
      regex "\\p{Latin}+", :Latin
    end
  end

  module HanTest
    Logos.define Token do
      regex "\\p{Han}+", :Han
    end
  end

  module NegatedGreekTest
    Logos.define Token do
      regex "\\P{Greek}+", :NonGreek
    end
  end

  describe "Unicode property classes" do
    it "reports exact Greek and ASCII word spans" do
      lexer = ScriptToken.lexer("λόγος can do unicode")
      stream = lexer.spanned
      [
        {ScriptToken::Greek, "λόγος", 0...10},
        {ScriptToken::Ascii, "can", 11...14},
        {ScriptToken::Ascii, "do", 15...17},
        {ScriptToken::Ascii, "unicode", 18...25},
      ].each do |variant, slice, span|
        stream.next.should eq({Logos::Result(ScriptToken, Nil).ok(variant), span})
        lexer.slice.should eq(slice)
      end
      stream.next.should eq(Iterator::Stop::INSTANCE)
    end

    it "reports exact Cyrillic word spans" do
      lexer = ScriptToken.lexer("До свидания")
      stream = lexer.spanned
      [{0...4, "До"}, {5...21, "свидания"}].each do |span, slice|
        stream.next.should eq({Logos::Result(ScriptToken, Nil).ok(ScriptToken::Cyrillic), span})
        lexer.slice.should eq(slice)
      end
      stream.next.should eq(Iterator::Stop::INSTANCE)
    end

    it "matches Latin script with \\p{Latin}" do
      lexer = Logos::Lexer(LatinTest::Token, String, Logos::NoExtras, Nil).new("Hello World")
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(LatinTest::Token, Nil))
      result.unwrap.should eq LatinTest::Token::Latin
      lexer.slice.should eq "Hello"
    end
  end

  it "matches non-Greek script with \\\\P{Greek}" do
    lexer = Logos::Lexer(NegatedGreekTest::Token, String, Logos::NoExtras, Nil).new("hello λόγος")
    result = lexer.next
    result.should_not be_nil
    result = result.as(Logos::Result(NegatedGreekTest::Token, Nil))
    result.unwrap.should eq NegatedGreekTest::Token::NonGreek
    lexer.slice.should eq "hello "
  end

  it "matches Han script with \\p{Han}" do
    lexer = Logos::Lexer(HanTest::Token, String, Logos::NoExtras, Nil).new("漢字")
    result = lexer.next
    result.should_not be_nil
    result = result.as(Logos::Result(HanTest::Token, Nil))
    result.unwrap.should eq HanTest::Token::Han
    lexer.slice.should eq "漢字"
  end
end
