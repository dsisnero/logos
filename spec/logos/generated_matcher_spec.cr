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

  it "keeps UTF-8 boundary validation for registered generated matchers" do
    lexer = Logos::Spec::GeneratedMatcher::InvalidUtf8OffsetToken.lexer("é")

    expect_raises(Exception, "Invalid Lexer bump") { lexer.next }
  end
end
