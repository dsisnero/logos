require "../spec_helper"
require "regex-automata"

module Logos::Spec::Binary
  Logos.define ByteToken do
    utf8 false
    error_type Nil

    token "\x00", :Zero
    token "\x42", :Byte42
    token "\xFF", :ByteFF
    # regex "[\x00-\xFF]", :AnyByte
  end

  describe "utf8 attribute" do
    it "lexes bytes with utf8 = false" do
      slice = Slice[0x00_u8, 0x42_u8, 0xFF_u8]
      input = String.new(slice)
      lexer = Logos::Lexer(ByteToken, String, Logos::NoExtras, Nil).new(input)
      tokens = [] of ByteToken
      while token = lexer.next
        break if token.is_a?(Iterator::Stop)
        result = token.as(Logos::Result(ByteToken, Nil))
        if result.ok?
          tokens << result.unwrap
        end
        # ignore errors (should not happen)
      end

      tokens.should eq([ByteToken::Zero, ByteToken::Byte42, ByteToken::ByteFF])
    end
  end

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
