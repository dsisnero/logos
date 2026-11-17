require "../spec_helper"

module Logos::Spec::Diagnostics
  Logos.define PriorityConflictToken do
    token "a", :LiteralA, priority: 10
    regex "[a]", :RegexA, priority: 10
  end

  Logos.define ImplicitPriorityConflict do
    regex %q{'(?:'?(?:[[:ascii:][^\\']]|\\[[:ascii:]]))*'}, :Problem
    regex %q{'(?:"?(?:[[:ascii:][^\\"]]|\\[[:ascii:]]))*'}, :Problem
  end

  @[Logos::Regex(:Problem, %q{'(?:'?(?:[[:ascii:][^\\']]|\\[[:ascii:]]))*'})]
  @[Logos::Regex(:Problem, %q{'(?:"?(?:[[:ascii:][^\\"]]|\\[[:ascii:]]))*'})]
  enum AnnotatedPriorityConflict
    Problem
  end

  logos_derive(AnnotatedPriorityConflict)

  Logos.define ShadowedPriorityTie do
    regex "a", :Low, priority: 2
    regex "[a]", :AlsoLow, priority: 2
    token "a", :High, priority: 9
  end

  @[Logos::Subpattern("example", "(a|)+")]
  @[Logos::Regex("(?&example)", variant: :Subpattern)]
  enum EmptySubpatternToken
    Subpattern
  end

  logos_derive(EmptySubpatternToken)

  Logos.define Utf8InvalidRegexToken do
    regex "\xFF", :Invalid
  end

  Logos.define Utf8InvalidTokenToken do
    token "\xFF", :Invalid
  end

  Logos.define Utf8InvalidRegexNullStarToken do
    regex "\x00.*", :Invalid, bytes: true
  end

  Logos.define Utf8InvalidRegexNullPlusToken do
    regex "\x00.+", :Invalid, bytes: true
  end

  @[Logos::Regex("\xFF", variant: :Invalid)]
  enum Utf8InvalidRegexAnnotatedToken
    Invalid
  end

  logos_derive(Utf8InvalidRegexAnnotatedToken)

  Logos.define GreedySkipWithoutConfigToken do
    skip_regex ".+", :Skip
    token "bar", :Bar
  end

  @[Logos::Subpattern("example", "(a|)+")]
  @[Logos::Regex("(?&example)+", variant: :Subpattern)]
  enum EmptySubpatternPlusToken
    Subpattern
  end

  logos_derive(EmptySubpatternPlusToken)
end

describe "logos diagnostics" do
  it "rejects the upstream implicit overlap even when both rules emit the same variant" do
    expect_raises(Exception, /can match simultaneously.*priority 4/) do
      Logos::Spec::Diagnostics::ImplicitPriorityConflict.lexer("").next
    end
    expect_raises(Exception, /can match simultaneously.*priority 4/) do
      Logos::Spec::Diagnostics::AnnotatedPriorityConflict.lexer("").next
    end
  end

  it "accepts a unique highest-priority rule over tied lower-priority rules" do
    results = Logos::Spec::Diagnostics::ShadowedPriorityTie.lex_all("a")
    results.map(&.unwrap).should eq([Logos::Spec::Diagnostics::ShadowedPriorityTie::High])
  end

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

  it "rejects empty-matching annotation subpatterns with + quantifier" do
    lexer = Logos::Spec::Diagnostics::EmptySubpatternPlusToken.lexer("a")
    expect_raises(Exception, /can match the empty string/) do
      lexer.next
    end
  end

  it "rejects greedy skip patterns without allow_greedy" do
    lexer = Logos::Spec::Diagnostics::GreedySkipWithoutConfigToken.lexer("bar")
    expect_raises(Exception, /allow_greedy/) do
      lexer.next
    end
  end

  it "rejects define-API patterns that can match invalid UTF-8 in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidRegexToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end

  it "rejects define-API token literals that can match invalid UTF-8 in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidTokenToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end

  it "rejects define-API byte-oriented null-prefix greedy regex in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidRegexNullStarToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end

  it "rejects define-API byte-oriented null-prefix plus regex in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidRegexNullPlusToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end

  it "rejects annotation API patterns that can match invalid UTF-8 in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidRegexAnnotatedToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end
end
