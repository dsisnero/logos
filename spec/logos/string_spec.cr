require "../spec_helper"
require "regex-automata"

module Logos::Spec::String
  pending "token variants with associated data (logos-gwz)" do
    it "parses string literals with escape sequences" do
      # Requires token variants with associated data (callbacks returning values)
      # Pattern: r#""([^"\\]+|\\.)*""# with callback lex_single_line_string
      # Callback handles escape sequences: \n, \r, \t, \0, \', \", \\, \xHH, \u{...}
    end

    it "works without cloning lexer" do
      # Test that lexer can parse strings without cloning
    end

    it "works with cloning lexer" do
      # Test that lexer cloning works correctly with string callbacks
    end
  end
end
