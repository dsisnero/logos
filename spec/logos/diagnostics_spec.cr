require "../spec_helper"

module Logos::Spec::Diagnostics
  Logos.define PriorityConflictToken do
    token "a", :LiteralA, priority: 10
    regex "[a]", :RegexA, priority: 10
  end

  @[Logos::Subpattern("example", "(a|)+")]
  @[Logos::Regex("(?&example)", variant: :Subpattern)]
  enum EmptySubpatternToken
    Subpattern
  end

  logos_derive(EmptySubpatternToken)
end

describe "logos diagnostics" do
  it "rejects ambiguous same-priority overlaps" do
    lexer = Logos::Spec::Diagnostics::PriorityConflictToken.lexer("a")
    expect_raises(Exception, /can match simultaneously/) do
      lexer.next
    end
  end

  it "rejects empty-matching annotation subpatterns" do
    lexer = Logos::Spec::Diagnostics::EmptySubpatternToken.lexer("a")
    expect_raises(Exception, /can match the empty string/) do
      lexer.next
    end
  end
end
