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
  end
end
