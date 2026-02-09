require "../spec_helper"
require "regex-automata"

module Logos::Spec::Derive
  pending "compile-time tests (Rust trybuild)" do
    it "passes all valid macro invocations" do
      # Rust trybuild tests for derive macro compile success
      # Not applicable to Crystal's macro system.
    end

    it "fails on invalid macro invocations with appropriate errors" do
      # Rust trybuild tests for compile failures
      # Not applicable to Crystal's macro system.
    end
  end
end
