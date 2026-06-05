require "./spec_helper"

describe "AST/HIR stack safety smoke parity" do
  it "builds and releases deeply nested AST structures without raising" do
    span = Regex::Syntax::AST::Span.splat(Regex::Syntax::AST::Position.new(0, 0, 0))
    ast = Regex::Syntax::AST::Ast.empty(span)

    200.times do |index|
      ast = Regex::Syntax::AST::Ast.group(
        Regex::Syntax::AST::Group.new(
          span,
          Regex::Syntax::AST::Group::Kind::Capture,
          ast.root,
          capture_index: index
        )
      )
    end

    ast.empty?.should be_false
    ast = Regex::Syntax::AST::Ast.empty(span)
    GC.collect
    ast.empty?.should be_true
  end

  it "builds and releases deeply nested HIR structures without raising" do
    hir = Regex::Syntax::Hir::Hir.empty

    100.times do
      hir = Regex::Syntax::Hir::Hir.capture(
        Regex::Syntax::Hir::Capture.new(hir.node, 1, nil)
      )
      hir = Regex::Syntax::Hir::Hir.repetition(
        Regex::Syntax::Hir::Repetition.new(hir.node, 0_u32, 1_u32, greedy: true)
      )
      hir = Regex::Syntax::Hir::Hir.concat([hir.node])
      hir = Regex::Syntax::Hir::Hir.alternation([hir.node])
    end

    hir.kind.should_not be_a(Regex::Syntax::Hir::Empty)
    hir = Regex::Syntax::Hir::Hir.empty
    GC.collect
    hir.kind.should be_a(Regex::Syntax::Hir::Empty)
  end
end
