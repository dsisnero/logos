require "../spec_helper"
require "regex-automata"

module Logos::Spec::UnicodeDot
  Logos.define DotToken do
    error_type Nil

    token "a", :A
    token "b", :B
    regex ".", :Dot
  end

  Logos.define DotOnlyToken do
    error_type Nil

    regex ".", :Dot
  end

  Logos.define BinaryDotToken do
    utf8 false
    error_type Nil

    regex ".", :Dot
  end

  describe "dot metacharacter" do
    describe "Unicode mode (utf8 = true)" do
      it "matches single ASCII character" do
        lexer = Logos::Lexer(DotToken, String, Logos::NoExtras, Nil).new("a")
        tokens = [] of DotToken
        while token = lexer.next
          break if token.is_a?(Iterator::Stop)
          result = token.as(Logos::Result(DotToken, Nil))
          if result.ok?
            tokens << result.unwrap
          end
        end
        tokens.should eq([DotToken::A])
      end

      it "consumes a full ASCII or Unicode code point" do
        ["a", "\u{E853}"].each do |source|
          lexer = DotOnlyToken.lexer(source)
          stream = lexer.spanned
          stream.next.should eq({Logos::Result(DotOnlyToken, Nil).ok(DotOnlyToken::Dot), 0...source.bytesize})
          lexer.slice.should eq(source)
          lexer.remainder.should be_empty
          stream.next.should eq(Iterator::Stop::INSTANCE)
        end
      end

      it "matches each character in sequence with dot only" do
        lexer = Logos::Lexer(DotOnlyToken, String, Logos::NoExtras, Nil).new("ab")
        tokens = [] of DotOnlyToken
        while token = lexer.next
          break if token.is_a?(Iterator::Stop)
          result = token.as(Logos::Result(DotOnlyToken, Nil))
          if result.ok?
            tokens << result.unwrap
          end
        end
        tokens.should eq([DotOnlyToken::Dot, DotOnlyToken::Dot])
      end

      it "does not match empty string" do
        lexer = Logos::Lexer(DotOnlyToken, String, Logos::NoExtras, Nil).new("")
        tokens = [] of DotOnlyToken
        while token = lexer.next
          break if token.is_a?(Iterator::Stop)
          result = token.as(Logos::Result(DotOnlyToken, Nil))
          if result.ok?
            tokens << result.unwrap
          end
        end
        tokens.should be_empty
      end
    end

    describe "binary mode (utf8 = false)" do
      it "matches single ASCII byte" do
        lexer = Logos::Lexer(BinaryDotToken, Slice(UInt8), Logos::NoExtras, Nil).new("a".to_slice)
        tokens = [] of BinaryDotToken
        while token = lexer.next
          break if token.is_a?(Iterator::Stop)
          result = token.as(Logos::Result(BinaryDotToken, Nil))
          if result.ok?
            tokens << result.unwrap
          end
        end
        tokens.should eq([BinaryDotToken::Dot])
      end

      it "matches each byte of Unicode character" do
        lexer = Logos::Lexer(BinaryDotToken, Slice(UInt8), Logos::NoExtras, Nil).new("🎉".to_slice)
        tokens = [] of BinaryDotToken
        while token = lexer.next
          break if token.is_a?(Iterator::Stop)
          result = token.as(Logos::Result(BinaryDotToken, Nil))
          if result.ok?
            tokens << result.unwrap
          end
        end
        # Dot matches any single byte, so we should get 4 tokens
        tokens.size.should eq(4)
      end

      it "matches invalid UTF-8 byte" do
        lexer = Logos::Lexer(BinaryDotToken, Slice(UInt8), Logos::NoExtras, Nil).new(Bytes[0xFF])
        tokens = [] of BinaryDotToken
        while token = lexer.next
          break if token.is_a?(Iterator::Stop)
          result = token.as(Logos::Result(BinaryDotToken, Nil))
          if result.ok?
            tokens << result.unwrap
          end
        end
        tokens.should eq([BinaryDotToken::Dot])
      end
    end
  end
end

module Logos::Spec::UnicodeDot::Mixed
  Logos.define Defined do
    utf8 false
    regex ".", :Dot, bytes: false, priority: 100
    regex ".", :InvalidUtf8, bytes: true, priority: 0
  end

  @[Logos::Options(utf8: false)]
  @[Logos::Regex(:Dot, ".", bytes: false, priority: 100)]
  @[Logos::Regex(:InvalidUtf8, ".", bytes: true, priority: 0)]
  enum Annotated
    Dot
    InvalidUtf8
  end

  logos_derive(Annotated)

  describe "mixed Unicode and byte dot rules" do
    it "preserves Unicode code points and matches invalid bytes with a separate rule" do
      {% for type in [Defined, Annotated] %}
        input = Bytes[0x61, 0xEE, 0xA1, 0x93, 0xFF]
        lexer = {{ type }}.lexer(input)
        stream = lexer.spanned
        stream.next.should eq({Logos::Result({{ type }}, Nil).ok({{ type }}::Dot), 0...1})
        lexer.slice.should eq(input[0, 1])
        stream.next.should eq({Logos::Result({{ type }}, Nil).ok({{ type }}::Dot), 1...4})
        lexer.slice.should eq(input[1, 3])
        stream.next.should eq({Logos::Result({{ type }}, Nil).ok({{ type }}::InvalidUtf8), 4...5})
        lexer.slice.should eq(input[4, 1])
        lexer.remainder.should be_empty
        stream.next.should eq(Iterator::Stop::INSTANCE)
      {% end %}
    end
  end
end
