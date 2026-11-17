require "../spec_helper"

module Logos::Spec::MatcherPriority
  Logos.define SkipPriority do
    skip_regex "(.|\\n)", :Ignore, priority: 1
    regex "[0-9]+", :Number do |lexer|
      Logos::Filter::Emit.new(lexer.slice)
    end
    regex "[!@#$%^&*]", :Op do |lexer|
      Logos::Filter::Emit.new(lexer.slice)
    end
  end

  @[Logos::Regex(:Ignore, "(.|\\n)", skip: true, priority: 1)]
  @[Logos::Regex(:Number, "[0-9]+", callback: ->(lexer) { Logos::Filter::Emit.new(lexer.slice) })]
  @[Logos::Regex(:Op, "[!@#$%^&*]", callback: ->(lexer) { Logos::Filter::Emit.new(lexer.slice) })]
  enum AnnotatedSkipPriority
    Ignore
    Number
    Op
  end

  logos_derive(AnnotatedSkipPriority)

  Logos.define UnicodePriority do
    regex "(é)+", :Implicit
    regex "é", :Explicit, priority: 3
  end

  @[Logos::Regex(:Implicit, "(é)+")]
  @[Logos::Regex(:Explicit, "é", priority: 3)]
  enum AnnotatedUnicodePriority
    Implicit
    Explicit
  end

  logos_derive(AnnotatedUnicodePriority)

  INPUT    = "123all letters are considered comments456\n            *other characters too& % 789😊! @ 012anything not a number or an op345 678 ^ 901"
  EXPECTED = [
    {"Number", "123", 0...3},
    {"Number", "456", 38...41},
    {"Op", "*", 54...55},
    {"Op", "&", 75...76},
    {"Op", "%", 77...78},
    {"Number", "789", 79...82},
    {"Op", "!", 86...87},
    {"Op", "@", 88...89},
    {"Number", "012", 90...93},
    {"Number", "345", 123...126},
    {"Number", "678", 127...130},
    {"Op", "^", 131...132},
    {"Number", "901", 133...136},
  ]

  def self.stream(lexer : Logos::Lexer) : Array({String, String, Logos::Span})
    lexer.spanned.map do |result, span|
      variant = result.unwrap
      {variant.to_s, result.payload_for!(variant, String), span}
    end.to_a
  end

  describe "matcher priority" do
    it "preserves Rust's low-priority fallback skip behavior in both declaration APIs" do
      Logos::Spec::MatcherPriority.stream(SkipPriority.lexer(INPUT)).should eq(EXPECTED)
      Logos::Spec::MatcherPriority.stream(AnnotatedSkipPriority.lexer(INPUT)).should eq(EXPECTED)
    end

    it "counts Unicode regexp scalars for implicit runtime priority in both declaration APIs" do
      UnicodePriority.lex_all("é").map(&.unwrap).should eq([UnicodePriority::Explicit])
      AnnotatedUnicodePriority.lex_all("é").map(&.unwrap).should eq([AnnotatedUnicodePriority::Explicit])
    end
  end
end
