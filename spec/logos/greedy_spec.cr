require "../spec_helper"
require "regex-automata"

module Logos::Spec::Greedy
  Logos.define Token do
    error_type Nil
    regex ".*", :All
  end

  Logos.define AllowedToken do
    error_type Nil
    regex ".*", :All, allow_greedy: true
  end
end

describe "greedy dot repetition" do
  it "raises without allow_greedy" do
    lexer = Logos::Lexer(Logos::Spec::Greedy::Token, String, Logos::NoExtras, Nil).new("abc")
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
end
