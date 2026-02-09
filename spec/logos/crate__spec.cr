require "../spec_helper"
require "regex-automata"

module Logos::Spec::Crate
  pending "crate attribute (Rust-specific)" do
    it "allows specifying custom crate path for logos" do
      # The crate attribute is a Rust-specific feature for macro hygiene.
      # Not applicable to Crystal's macro system.
    end
  end
end
