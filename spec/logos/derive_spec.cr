require "../spec_helper"
require "regex-automata"

module Logos::Spec::Derive
  it "skips Rust trybuild tests (not applicable)" do
    # Rust trybuild tests for derive macro compile success/failure.
    # Not applicable to Crystal's macro system.
    true.should be_true
  end
end
