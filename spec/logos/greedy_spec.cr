require "../spec_helper"
require "regex-automata"

module Logos::Spec::Greedy
  Logos.define Token do
    error_type Nil
    regex ".*", :All
  end

  Logos.define GreedyInGroupToken do
    error_type Nil
    regex "(a|b.*)", :All
  end

  Logos.define AllowedToken do
    error_type Nil
    regex ".+", :All, allow_greedy: true
  end

  Logos.define AllowedInGroupToken do
    error_type Nil
    regex "(a|b.*)", :All, allow_greedy: true
  end
end

describe "greedy dot repetition" do
  it "raises without allow_greedy for plain .*" do
    lexer = Logos::Lexer(Logos::Spec::Greedy::Token, String, Logos::NoExtras, Nil).new("abc")
    expect_raises(Exception, /allow_greedy/) do
      lexer.next
    end
  end

  it "raises without allow_greedy for .* inside a group" do
    lexer = Logos::Lexer(Logos::Spec::Greedy::GreedyInGroupToken, String, Logos::NoExtras, Nil).new("abc")
    expect_raises(Exception, /allow_greedy/) do
      lexer.next
    end
  end

  it "allows allow_greedy" do
    lexer = Logos::Lexer(Logos::Spec::Greedy::AllowedToken, String, Logos::NoExtras, Nil).new("abc")
    result = lexer.next
    result = result.as(Logos::Result(Logos::Spec::Greedy::AllowedToken, Nil))
    result.ok?.should be_true
    result.unwrap.should eq(Logos::Spec::Greedy::AllowedToken::All)
  end

  it "allows allow_greedy for .* inside a group" do
    lexer = Logos::Lexer(Logos::Spec::Greedy::AllowedInGroupToken, String, Logos::NoExtras, Nil).new("abc")
    result = lexer.next
    result = result.as(Logos::Result(Logos::Spec::Greedy::AllowedInGroupToken, Nil))
    result.ok?.should be_true
    result.unwrap.should eq(Logos::Spec::Greedy::AllowedInGroupToken::All)
  end
end
