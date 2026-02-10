require "../spec_helper"
require "regex-automata"

module Logos::Spec::Properties
  module GreekTest
    Logos.define Token do
      regex "\\p{Greek}+", :Greek
    end
  end

  module CyrillicTest
    Logos.define Token do
      regex "\\p{Cyrillic}+", :Cyrillic
    end
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
    it "matches Greek script with \\p{Greek}" do
      lexer = Logos::Lexer(GreekTest::Token, String, Logos::NoExtras, Nil).new("λόγος")
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(GreekTest::Token, Nil))
      result.unwrap.should eq GreekTest::Token::Greek
      lexer.slice.should eq "λόγος"
    end

    it "matches Cyrillic script with \\p{Cyrillic}" do
      lexer = Logos::Lexer(CyrillicTest::Token, String, Logos::NoExtras, Nil).new("До свидания")
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(CyrillicTest::Token, Nil))
      result.unwrap.should eq CyrillicTest::Token::Cyrillic
      lexer.slice.should eq "До"
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
