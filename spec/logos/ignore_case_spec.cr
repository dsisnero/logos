require "../spec_helper"
require "regex-automata"

module Logos::Spec::IgnoreCase
  # ignore_ascii_case tests from Rust ignore_case.rs
  module IgnoreAsciiCase
    pending "ignore_ascii_case: tokens with ignore(case)" do
      it "matches case-insensitive ASCII tokens" do
        # Requires ignore(case) support for tokens
        # Tokens: lOwERCaSe, or, UppeRcaSE, etc. with ignore(case)
        # Both utf8 = false mode and regular mode
      end
    end

    pending "ignore_ascii_case: regex with ignore(case)" do
      it "matches case-insensitive ASCII regex patterns" do
        # Requires ignore(case) support for regex patterns
        # Patterns: a, bc, [de], f+, gg?, [h-k] with ignore(case)
      end
    end
  end

  # ignore_case tests (full Unicode case folding)
  module IgnoreCase
    pending "ignore_case: tokens with Unicode case folding" do
      it "matches case-insensitive Unicode tokens" do
        # Requires full Unicode case folding for ignore(case)
        # Tokens: élÉphAnt, ÉlèvE, à with ignore(case)
      end
    end

    pending "ignore_case: regex with Unicode case folding" do
      it "matches case-insensitive Unicode regex patterns" do
        # Requires Unicode case folding for regex patterns
        # Patterns: [abcéà]+, [0-9]+, ééààé with ignore(case)
      end
    end
  end
end
