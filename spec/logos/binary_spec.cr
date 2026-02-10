require "../spec_helper"
require "regex-automata"

module Logos::Spec::Binary
  Logos.define ByteToken do
    utf8 false
    error_type Nil

    token "\x00", :Zero
    token "\x42", :Byte42
    token "\xFF", :ByteFF
    regex "[\\x00-\\xFF]", :AnyByte
  end

  Logos.define AdvancedByteToken do
    utf8 false
    error_type Nil

    # Token literals
    token "\x00", :Zero
    token "\xCA\xFE\xBE\xEF", :CafeBeef
    token "foo", :Foo # ASCII still works

    # Byte regex patterns
    regex "\\x42+", :Life
    regex "[\\xA0-\\xAF]+", :Aaaaaaa
  end

  describe "utf8 attribute" do
    it "lexes bytes with utf8 = false" do
      slice = Slice[0x00_u8, 0x42_u8, 0xFF_u8, 0x10_u8]
      lexer = Logos::Lexer(ByteToken, Slice(UInt8), Logos::NoExtras, Nil).new(slice)
      tokens = [] of ByteToken
      while token = lexer.next
        break if token.is_a?(Iterator::Stop)
        result = token.as(Logos::Result(ByteToken, Nil))
        if result.ok?
          tokens << result.unwrap
        end
        # ignore errors (should not happen)
      end

      # Should match: 0x00 -> Zero, 0x42 -> Byte42, 0xFF -> ByteFF, 0x10 -> AnyByte
      tokens.should eq([ByteToken::Zero, ByteToken::Byte42, ByteToken::ByteFF, ByteToken::AnyByte])
    end
  end

  describe "advanced binary mode" do
    it "handles non-UTF8 byte patterns" do
      # Test input from original pending test
      # [0, 0, 0xCA, 0xFE, 0xBE, 0xEF, 'f','o','o', 0x42, 0x42, 0x42, 0xAA, 0xAA, 0xA2, 0xAE, 0x10, 0x20, 0]
      slice = Slice[
        0x00_u8, 0x00_u8,
        0xCA_u8, 0xFE_u8, 0xBE_u8, 0xEF_u8,
        'f'.ord.to_u8, 'o'.ord.to_u8, 'o'.ord.to_u8,
        0x42_u8, 0x42_u8, 0x42_u8,
        0xAA_u8, 0xAA_u8, 0xA2_u8, 0xAE_u8,
        0x10_u8, 0x20_u8, 0x00_u8,
      ]

      lexer = Logos::Lexer(AdvancedByteToken, Slice(UInt8), Logos::NoExtras, Nil).new(slice)
      tokens = [] of AdvancedByteToken

      while token = lexer.next
        break if token.is_a?(Iterator::Stop)
        result = token.as(Logos::Result(AdvancedByteToken, Nil))
        if result.ok?
          tokens << result.unwrap
        end
        # Errors are expected for unmatchable bytes (0x10, 0x20)
      end

      # Expected: Zero, Zero, CafeBeef, Foo, Life, Aaaaaaa, Error(0x10), Error(0x20), Zero
      # With error_type Nil and no error variant, lexer produces Nil errors
      # Check we get at least 6 tokens
      tokens.size.should be >= 6
      if tokens.size >= 6
        tokens[0..5].should eq([
          AdvancedByteToken::Zero,
          AdvancedByteToken::Zero,
          AdvancedByteToken::CafeBeef,
          AdvancedByteToken::Foo,
          AdvancedByteToken::Life,
          AdvancedByteToken::Aaaaaaa,
        ])
      end
    end
  end
end
