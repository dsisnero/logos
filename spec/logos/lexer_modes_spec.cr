require "../spec_helper"
require "regex-automata"

module Logos::Spec::LexerModes
  pending "lexer morphing (logos-morph)" do
    it "switches from outer lexer to inner lexer for string parsing" do
      # Requires morph support (sublexers)
      # Outer token: StartString ("\"")
      # Inner tokens: Text, EscapedNewline, EscapedCodepoint, EscapedOctal, EscapedQuote, EndString
    end

    it "returns to outer lexer after string ends" do
      # After inner lexer consumes EndString, should return to outer lexer
    end

    it "handles nested lexer modes" do
      # Possibly nested morphing (not in test)
    end
  end
end
