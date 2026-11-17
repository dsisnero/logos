require "../spec_helper"
require "regex-automata"

module Logos::Spec::GeneratedMatcher
  Logos.register_generated_matcher(
    "OffsetToken",
    ->(input : Bytes, offset : Int32) : Logos::GeneratedMatch do
      if offset < input.size && input[offset] == 'a'.ord.to_u8
        {1, [::Regex::Automata::DFA::PatternID.new(0)]}
      end
    end
  )

  Logos.define OffsetToken do
    token "a", :A
  end

  Logos.register_generated_matcher(
    "GeneratedDefaultPriorityToken",
    ->(input : Bytes, offset : Int32) : Logos::GeneratedMatch do
      if offset < input.size
        {1, StaticArray[::Regex::Automata::PatternID.new(0), ::Regex::Automata::PatternID.new(1)]}
      end
    end,
    [2, 2],
  )

  Logos.define GeneratedDefaultPriorityToken do
    skip_regex ".", :Ignore, priority: 1
    regex "[0-9]+", :Number
  end

  Logos.register_generated_matcher(
    "GeneratedDuplicateVariantToken",
    ->(input : Bytes, offset : Int32) : Logos::GeneratedMatch do
      if offset < input.size
        {1, StaticArray[::Regex::Automata::PatternID.new(0), ::Regex::Automata::PatternID.new(1)]}
      end
    end,
    [2, 2],
  )

  Logos.define GeneratedDuplicateVariantToken do
    regex "a", :A
    regex "[a]", :A
  end

  Logos.register_generated_matcher(
    "InvalidUtf8OffsetToken",
    ->(input : Bytes, offset : Int32) : Logos::GeneratedMatch do
      if offset < input.size
        {1, [::Regex::Automata::DFA::PatternID.new(0)]}
      end
    end
  )

  Logos.define InvalidUtf8OffsetToken do
    regex ".", :Character
  end
end

describe "generated matchers" do
  it "scans the original input at the current lexer offset" do
    lexer = Logos::Spec::GeneratedMatcher::OffsetToken.lexer("aa")

    lexer.next.as(Logos::Result(Logos::Spec::GeneratedMatcher::OffsetToken, Nil)).unwrap.should eq(Logos::Spec::GeneratedMatcher::OffsetToken::A)
    lexer.next.as(Logos::Result(Logos::Spec::GeneratedMatcher::OffsetToken, Nil)).unwrap.should eq(Logos::Spec::GeneratedMatcher::OffsetToken::A)
    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end

  it "prefers the inferred generated priority over an explicitly weaker skip" do
    type = Logos::Spec::GeneratedMatcher::GeneratedDefaultPriorityToken
    results = type.lexer("7").spanned.to_a
    results.map { |result, span| {result.unwrap.to_s, span} }.should eq([{"Number", 0...1}])
  end

  it "rejects tied generated rules for the same variant" do
    lexer = Logos::Spec::GeneratedMatcher::GeneratedDuplicateVariantToken.lexer("a")
    expect_raises(Exception, /can match simultaneously/) { lexer.next }
  end

  it "keeps UTF-8 boundary validation for registered generated matchers" do
    lexer = Logos::Spec::GeneratedMatcher::InvalidUtf8OffsetToken.lexer("é")

    expect_raises(Exception, "Invalid Lexer bump") { lexer.next }
  end
end
