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
end

describe "generated matchers" do
  it "scans the original input at the current lexer offset" do
    lexer = Logos::Spec::GeneratedMatcher::OffsetToken.lexer("aa")

    lexer.next.as(Logos::Result(Logos::Spec::GeneratedMatcher::OffsetToken, Nil)).unwrap.should eq(Logos::Spec::GeneratedMatcher::OffsetToken::A)
    lexer.next.as(Logos::Result(Logos::Spec::GeneratedMatcher::OffsetToken, Nil)).unwrap.should eq(Logos::Spec::GeneratedMatcher::OffsetToken::A)
    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end
end
