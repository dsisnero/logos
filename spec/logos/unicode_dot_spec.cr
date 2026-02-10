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

      it "matches single Unicode character with dot" do
        lexer = Logos::Lexer(DotOnlyToken, String, Logos::NoExtras, Nil).new("🎉")
        tokens = [] of DotOnlyToken
        while token = lexer.next
          break if token.is_a?(Iterator::Stop)
          result = token.as(Logos::Result(DotOnlyToken, Nil))
          if result.ok?
            tokens << result.unwrap
          end
        end
        tokens.should eq([DotOnlyToken::Dot])
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
