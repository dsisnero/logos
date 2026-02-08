require "../spec_helper"
require "regex-automata"

module Logos::Spec::Binary
  pending "binary mode (utf8 = false)" do
    it "handles non-UTF8 byte patterns" do
      # Requires utf8 = false support
      # Tokens: "foo" (ASCII), b"\x42+" (byte regex), b"[\xA0-\xAF]+" (byte range)
      # Token: b"\xCA\xFE\xBE\xEF" (CafeBeef), b"\x00" (Zero)
    end
  end
end
