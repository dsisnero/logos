require "../spec_helper"
require "regex-automata"

module Logos::Spec::Nostd
  it "ignores no_std environment (Rust-specific)" do
    # Rust-specific feature: compiling without std (using core)
    # Not applicable to Crystal.
    true.should be_true
  end
end
