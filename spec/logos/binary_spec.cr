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

  Logos.define ComplexBinaryToken do
    utf8 false
    error_type Nil

    regex "\\x00|\\x01", :ZeroOrOne
    regex "[\\x02-\\x05]+", :TwoToFive
    regex "\\x06\\x07", :SixSeven
    regex ".", :AnyByte
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
    it "handles non-UTF8 byte patterns with exact upstream assertions" do
      slice = Slice[
        0x00_u8, 0x00_u8,
        0xCA_u8, 0xFE_u8, 0xBE_u8, 0xEF_u8,
        'f'.ord.to_u8, 'o'.ord.to_u8, 'o'.ord.to_u8,
        0x42_u8, 0x42_u8, 0x42_u8,
        0xAA_u8, 0xAA_u8, 0xA2_u8, 0xAE_u8,
        0x10_u8, 0x20_u8, 0x00_u8,
      ]

      lexer = Logos::Lexer(AdvancedByteToken, Slice(UInt8), Logos::NoExtras, Nil).new(slice)

      expectations = [
        {:ok, AdvancedByteToken::Zero, Slice[0x00_u8], 0...1},
        {:ok, AdvancedByteToken::Zero, Slice[0x00_u8], 1...2},
        {:ok, AdvancedByteToken::CafeBeef, Slice[0xCA_u8, 0xFE_u8, 0xBE_u8, 0xEF_u8], 2...6},
        {:ok, AdvancedByteToken::Foo, Slice['f'.ord.to_u8, 'o'.ord.to_u8, 'o'.ord.to_u8], 6...9},
        {:ok, AdvancedByteToken::Life, Slice[0x42_u8, 0x42_u8, 0x42_u8], 9...12},
        {:ok, AdvancedByteToken::Aaaaaaa, Slice[0xAA_u8, 0xAA_u8, 0xA2_u8, 0xAE_u8], 12...16},
        {:error, nil, Slice[0x10_u8], 16...17},
        {:error, nil, Slice[0x20_u8], 17...18},
        {:ok, AdvancedByteToken::Zero, Slice[0x00_u8], 18...19},
      ]

      expectations.each do |kind, expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(AdvancedByteToken, Nil))
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)

        case kind
        when :ok
          result.ok?.should be_true
          result.unwrap.should eq(expected_token)
        when :error
          result.error?.should be_true
        end
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "complex binary regex patterns" do
    it "handles alternation, repetition, concatenation, and dot" do
      slice = Slice[0x00_u8, 0x01_u8, 0x02_u8, 0x03_u8, 0x04_u8, 0x06_u8, 0x07_u8, 0xFF_u8]
      lexer = Logos::Lexer(ComplexBinaryToken, Slice(UInt8), Logos::NoExtras, Nil).new(slice)
      tokens = [] of ComplexBinaryToken
      while token = lexer.next
        break if token.is_a?(Iterator::Stop)
        result = token.as(Logos::Result(ComplexBinaryToken, Nil))
        if result.ok?
          tokens << result.unwrap
        end
      end

      tokens.should eq([
        ComplexBinaryToken::ZeroOrOne,
        ComplexBinaryToken::ZeroOrOne,
        ComplexBinaryToken::TwoToFive,
        ComplexBinaryToken::SixSeven,
        ComplexBinaryToken::AnyByte,
      ])
    end
  end
end

module Logos::Spec::Binary::PatternOptions
  Logos.define Defined do
    utf8 false
    subpattern :digit, %q(\d), bytes: false
    subpattern :raw, ".", bytes: true
    regex "~(?&digit)(?&raw)", :Mixed
  end

  @[Logos::Options(utf8: false)]
  @[Logos::Subpattern(:digit, %q(\d), bytes: false)]
  @[Logos::Subpattern(:raw, ".", bytes: true)]
  @[Logos::Regex(:Mixed, "~(?&digit)(?&raw)")]
  enum Annotated
    Mixed
  end

  logos_derive(Annotated)

  Logos.define SafeByteRules do
    subpattern :ascii_word, %q(\w+), bytes: true
    token "!", :Mark, bytes: true
    regex "(?&ascii_word)", :Word
  end

  Logos.define RawRegex do
    utf8 false
    regex "\xFF+", :Marker, bytes: true
  end

  Logos.define InvalidUnusedSubpattern do
    subpattern :raw, ".", bytes: true
    token "!", :Mark
  end

  Logos.define InvalidFoldedLiteral do
    token "\xFF", :Marker, ignore_case: true
  end

  describe "pattern encoding" do
    it "preserves raw bytes supplied in regex text" do
      input = Bytes[0xFF, 0xFF]
      lexer = RawRegex.lexer(input)
      stream = lexer.spanned
      stream.next.should eq({Logos::Result(RawRegex, Nil).ok(RawRegex::Marker), 0...2})
      lexer.slice.should eq(input)
      stream.next.should eq(Iterator::Stop::INSTANCE)
    end

    it "rejects byte rules that could break string boundaries" do
      expect_raises(Exception, /UTF-8.*byte-oriented/) { InvalidUnusedSubpattern.lexer("!").next }
      expect_raises(Exception, /UTF-8.*byte-oriented/) { InvalidFoldedLiteral.lexer("").next }
    end

    it "scopes each subpattern independently of a byte regex and lexer" do
      {% for type in [Defined, Annotated] %}
        input = Bytes[0x7E, 0xD9, 0xA1, 0xFF, 0x3F]
        lexer = {{ type }}.lexer(input)
        stream = lexer.spanned
        stream.next.should eq({Logos::Result({{ type }}, Nil).ok({{ type }}::Mixed), 0...4})
        lexer.slice.should eq(input[0, 4])
        stream.next.should eq({Logos::Result({{ type }}, Nil).error(nil), 4...5})
        lexer.slice.should eq(input[4, 1])
        stream.next.should eq(Iterator::Stop::INSTANCE)
      {% end %}
    end

    it "accepts ASCII-only byte rules and keeps byte subpatterns ASCII in a string lexer" do
      lexer = SafeByteRules.lexer("!wordé")
      stream = lexer.spanned
      stream.next.should eq({Logos::Result(SafeByteRules, Nil).ok(SafeByteRules::Mark), 0...1})
      stream.next.should eq({Logos::Result(SafeByteRules, Nil).ok(SafeByteRules::Word), 1...5})
      lexer.slice.should eq("word")
      stream.next.should eq({Logos::Result(SafeByteRules, Nil).error(nil), 5...7})
      lexer.slice.should eq("é")
      stream.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
