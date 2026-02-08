require "../spec_helper"
require "regex-automata"

module Logos::Spec::Colors
  # Define token enum using Logos.define
  Logos.define Token do
    token " ", :Whitespace
    regex "red", :Red
    regex "green", :Green
    regex "blue", :Blue
    regex "[a-zA-Z0-9_$]+", :NoHighlight
  end
end

describe "Colors test" do
  it "matches colors correctly" do
    source = "red fred redf green fgreen greenf blue bluef fblue"
    lexer = Logos::Lexer(Logos::Spec::Colors::Token, String, Logos::NoExtras, Nil).new(source)

    expected = [
      {Logos::Spec::Colors::Token::Red, "red", 0...3},
      {Logos::Spec::Colors::Token::Whitespace, " ", 3...4},
      {Logos::Spec::Colors::Token::NoHighlight, "fred", 4...8},
      {Logos::Spec::Colors::Token::Whitespace, " ", 8...9},
      {Logos::Spec::Colors::Token::NoHighlight, "redf", 9...13},
      {Logos::Spec::Colors::Token::Whitespace, " ", 13...14},
      {Logos::Spec::Colors::Token::Green, "green", 14...19},
      {Logos::Spec::Colors::Token::Whitespace, " ", 19...20},
      {Logos::Spec::Colors::Token::NoHighlight, "fgreen", 20...26},
      {Logos::Spec::Colors::Token::Whitespace, " ", 26...27},
      {Logos::Spec::Colors::Token::NoHighlight, "greenf", 27...33},
      {Logos::Spec::Colors::Token::Whitespace, " ", 33...34},
      {Logos::Spec::Colors::Token::Blue, "blue", 34...38},
      {Logos::Spec::Colors::Token::Whitespace, " ", 38...39},
      {Logos::Spec::Colors::Token::NoHighlight, "bluef", 39...44},
      {Logos::Spec::Colors::Token::Whitespace, " ", 44...45},
      {Logos::Spec::Colors::Token::NoHighlight, "fblue", 45...50},
    ]

    expected.each do |expected_token, expected_slice, expected_range|
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(Logos::Spec::Colors::Token, Nil))
      result.unwrap.should eq(expected_token)
      lexer.slice.should eq(expected_slice)
      lexer.span.should eq(expected_range)
    end

    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end
end
