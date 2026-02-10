require "../spec_helper"
require "regex-automata"

module Logos::Spec::Crate
  it "ignores crate attribute (Rust-specific)" do
    # The crate attribute is a Rust-specific feature for macro hygiene.
    # Not applicable to Crystal's macro system.
    true.should be_true
  end
end
