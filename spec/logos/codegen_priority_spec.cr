require "../spec_helper"
{% if flag?(:codegen_library) %}
  require "../../src/logos_codegen"

  describe Logos::Codegen do
    it "resolves the highest priority independently of pattern order" do
      patterns = JSON.parse(%([{"resolved_priority":1},{"resolved_priority":3}])).as_a
      Logos::Codegen.resolve_accept([0, 1], patterns).should eq(1)
      Logos::Codegen.resolve_accept([1, 0], patterns).should eq(1)
      Logos::Codegen.resolve_accept([] of Int32, patterns).should be_nil
    end

    it "preserves first-match ties and rejects explicit ambiguity" do
      patterns = JSON.parse(%([{"resolved_priority":3},{"resolved_priority":3}])).as_a
      Logos::Codegen.resolve_accept([1, 0], patterns).should eq(1)
      patterns = JSON.parse(%([{"resolved_priority":3,"priority_explicit":true},{"resolved_priority":3,"priority_explicit":true}])).as_a
      expect_raises(Exception, /can match simultaneously/) { Logos::Codegen.resolve_accept([0, 1], patterns) }
    end
  end
{% end %}
