require "./spec_helper"

private class HirUtilityVisitRecorder
  include Regex::Syntax::Hir::Visitor

  getter events = [] of String

  def start : Nil
    @events << "start"
  end

  def finish : Array(String)
    @events << "finish"
    @events
  end

  def visit_pre(hir : Regex::Syntax::Hir::Hir) : Nil
    @events << "pre:#{hir.node.class.name.split("::").last}"
  end

  def visit_post(hir : Regex::Syntax::Hir::Hir) : Nil
    @events << "post:#{hir.node.class.name.split("::").last}"
  end

  def visit_alternation_in : Nil
    @events << "alt:in"
  end

  def visit_concat_in : Nil
    @events << "concat:in"
  end
end

describe "HIR utility parity" do
  it "exposes literal extraction value objects and predicates" do
    kind = Regex::Syntax::Hir::LiteralExtraction::ExtractKind::Prefix
    kind.prefix?.should be_true
    kind.is_prefix.should be_true
    kind.suffix?.should be_false

    literal = Regex::Syntax::Hir::LiteralExtraction::Literal.exact("ab")
    literal.as_bytes.should eq("ab".bytes.to_a)
    literal.into_bytes.should eq("ab".bytes.to_a)
    literal.len.should eq(2)
    literal.empty?.should be_false

    seq = Regex::Syntax::Hir::LiteralExtraction::Seq.singleton(literal)
    seq.finite?.should be_true
    seq.exact?.should be_true
    seq.min_literal_len.should eq(2)
    seq.max_literal_len.should eq(2)
  end

  it "exposes literal extraction combinators and extractor configuration" do
    lhs = Regex::Syntax::Hir::LiteralExtraction::Seq.singleton(
      Regex::Syntax::Hir::LiteralExtraction::Literal.exact("ab")
    )
    rhs = Regex::Syntax::Hir::LiteralExtraction::Seq.singleton(
      Regex::Syntax::Hir::LiteralExtraction::Literal.inexact("cd")
    )
    lhs.cross_forward(rhs)
    lhs.literals.should eq([
      Regex::Syntax::Hir::LiteralExtraction::Literal.inexact("abcd"),
    ])

    extractor = Regex::Syntax::Hir::LiteralExtraction::Extractor.new
      .kind(Regex::Syntax::Hir::LiteralExtraction::ExtractKind::Suffix)
      .limit_class(3)
      .limit_repeat(4)
      .limit_literal_len(5)
      .limit_total(6)
    seq = extractor.extract(Regex::Syntax.parse("(foo|bar)baz"))
    seq.finite?.should be_true
    seq.literals.should_not be_nil
  end

  it "prints HIR nodes through the public printer surface" do
    printer = Regex::Syntax::Hir::Printer.new
    io = IO::Memory.new
    printer.print(Regex::Syntax.parse("a|b"), io)
    io.to_s.should eq("[ab]")

    io = IO::Memory.new
    printer.print(Regex::Syntax.parse("(?m)^"), io)
    io.to_s.should eq("(?m:^)")

    io = IO::Memory.new
    printer.print(Regex::Syntax.parse("a{1,5}?"), io)
    io.to_s.should eq("a{1,5}?")
  end

  it "visits HIR nodes in depth-first order through the public visitor API" do
    hir = Regex::Syntax.parse("a(b|c)d")
    events = Regex::Syntax::Hir.visit(hir, HirUtilityVisitRecorder.new)

    events.should eq([
      "start",
      "pre:Concat",
      "pre:Literal",
      "post:Literal",
      "concat:in",
      "pre:Capture",
      "pre:Alternation",
      "pre:Literal",
      "post:Literal",
      "alt:in",
      "pre:Literal",
      "post:Literal",
      "post:Alternation",
      "post:Capture",
      "concat:in",
      "pre:Literal",
      "post:Literal",
      "post:Concat",
      "finish",
    ])
  end
end
