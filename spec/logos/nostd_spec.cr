require "../spec_helper"
require "regex-automata"

module Logos::Spec::Nostd
  pending "no_std environment (Rust-specific)" do
    it "works without the standard library" do
      # Rust-specific feature: compiling without std (using core)
      # Not applicable to Crystal.
    end
  end
end
