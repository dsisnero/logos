require "../spec_helper"

module Logos::Spec::Navigation
  Logos.define Token do
    extras Array(String)
    skip_token " ", :Space
    regex "[éλ]", :Letter do |lexer|
      lexer.extras << lexer.slice
      Logos::Filter::Emit.new(lexer.slice)
    end
  end

  Logos.define OtherMode do
    extras Array(String)
    error_type String do |lexer|
      "bad:#{lexer.slice}"
    end
    skip_token " ", :Space
    token "λ", :Lambda
  end

  Logos.define ConvertedMode do
    extras Array(Int32)
    error_type String
    skip_token " ", :Space
    token "λ", :Lambda
  end

  class OpaqueExtras
    getter seen = [] of String
  end

  describe "lexer navigation" do
    it "clones a spanned cursor and leaves the original extras independent" do
      lexer = Token.lexer("é ? λ ")
      stream = lexer.spanned
      first, span = stream.next.as({Logos::Result(Token, Nil), Logos::Span})
      span.should eq(0...2)

      copy = stream.clone
      copy.lexer.source.should be(lexer.source)
      copy.lexer.span.should eq(0...2)
      copy.lexer.remainder.should eq(" ? λ ")
      copy.lexer.extras << "copy"

      error, span = copy.next.as({Logos::Result(Token, Nil), Logos::Span})
      error.unwrap_error.should be_nil
      span.should eq(3...4)
      copy.lexer.slice.should eq("?")
      letter, span = copy.next.as({Logos::Result(Token, Nil), Logos::Span})
      letter.payload_for!(Token::Letter, String).should eq("λ")
      span.should eq(5...7)
      copy.next.should eq(Iterator::Stop::INSTANCE)
      copy.lexer.span.should eq(8...8)
      copy.lexer.remainder.should be_empty

      first.payload_for!(Token::Letter, String).should eq("é")
      lexer.span.should eq(0...2)
      lexer.extras.should eq(["é"])
      copy.lexer.extras.should eq(["é", "copy", "λ"])
      original_error, span = stream.next.as({Logos::Result(Token, Nil), Logos::Span})
      original_error.error?.should be_true
      span.should eq(3...4)
    end

    it "keeps an opaque extras object usable when it has no clone method" do
      extras = OpaqueExtras.new
      lexer = Logos::Lexer(Token, String, OpaqueExtras, Nil).new("é", extras)
      lexer.clone.extras.should be(extras)
    end

    it "morphs into the destination error type and preserves the current byte range" do
      lexer = Token.lexer("é ? λ")
      lexer.next

      inner = lexer.morph(OtherMode)
      inner.span.should eq(0...2)
      inner.slice.should eq("é")
      inner.remainder.should eq(" ? λ")
      inner.extras.should be(lexer.extras)
      inner.callback_value.should be_nil

      error = inner.next.as(Logos::Result(OtherMode, String))
      error.unwrap_error.should eq("bad:?")
      inner.span.should eq(3...4)

      converted = inner.morph(ConvertedMode) { |extras| extras.map(&.bytesize) }
      converted.extras.should eq([2])
      converted.span.should eq(3...4)
      converted.remainder.should eq(" λ")
      converted.next.as(Logos::Result(ConvertedMode, String)).unwrap.should eq(ConvertedMode::Lambda)
      converted.span.should eq(5...7)
      converted.next.should eq(Iterator::Stop::INSTANCE)
      inner.span.should eq(3...4)
    end

    it "rejects invalid navigation without moving the current byte range" do
      lexer = Token.lexer("éλ")
      lexer.next
      lexer.span.should eq(0...2)
      lexer.read_u8.should eq(0xce_u8)
      lexer.read_bytes(2).should eq("λ".to_slice)
      expect_raises(Exception, "Invalid Lexer bump") { lexer.bump(1) }
      lexer.span.should eq(0...2)
      expect_raises(Exception, "Invalid Lexer bump") { lexer.bump(Int32::MAX) }
      lexer.span.should eq(0...2)
      lexer.remainder.should eq("λ")
      lexer.read_u8(Int32::MAX).should be_nil
      lexer.read_bytes(1, Int32::MAX).should be_nil
      lexer.next.as(Logos::Result(Token, Nil)).payload_for!(Token::Letter, String).should eq("λ")
    end
  end
end
