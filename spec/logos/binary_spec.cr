require "../spec_helper"
require "regex-automata"

module Logos::Spec::Binary
  pending "utf8 attribute (logos-utf8)" do
    it "supports utf8 = false for byte-level lexing" do
      # Requires utf8 attribute support: #[logos(utf8 = false)]
      # This enables byte patterns (b"...") and disables UTF-8 validation
    end
  end

  pending "binary mode (utf8 = false)" do
    it "handles non-UTF8 byte patterns" do
      # Requires utf8 = false support
      # Tokens: "foo" (ASCII), b"\x42+" (byte regex), b"[\xA0-\xAF]+" (byte range)
      # Token: b"\xCA\xFE\xBE\xEF" (CafeBeef), b"\x00" (Zero)
      # Test input: [0, 0, 0xCA, 0xFE, 0xBE, 0xEF, 'f','o','o', 0x42, 0x42, 0x42, 0xAA, 0xAA, 0xA2, 0xAE, 0x10, 0x20, 0]
      # Expected tokens: Zero, Zero, CafeBeef, Foo, Life, Aaaaaaa, Error, Error, Zero
    end
  end
end
