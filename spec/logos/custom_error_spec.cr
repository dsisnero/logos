require "../spec_helper"
require "regex-automata"

module Logos::Spec::CustomError
  pending "token variants with associated data (logos-gwz)" do
    it "handles custom error types with callbacks" do
      # Requires token variants with associated data (callbacks returning values)
      # Test: Lexing numbers with custom error (NumberNotEven, NumberTooLong)
      # Pattern: [0-9]+ with callback parse_number that returns Result<u32, LexingError>
    end

    it "handles error callbacks with extras" do
      # Requires error callbacks that can mutate extras
      # Test: Error callbacks for TokenA and TokenB that push to extras vector
    end
  end
end
