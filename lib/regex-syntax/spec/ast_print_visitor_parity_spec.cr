require "./spec_helper"

private def print_ast(pattern : String, *, unicode : Bool = true, ignore_whitespace : Bool = false, octal : Bool = false) : String
  ast = Regex::Syntax::AstParser.new(
    unicode: unicode,
    ignore_whitespace: ignore_whitespace,
    octal: octal
  ).parse(pattern)
  io = IO::Memory.new
  Regex::Syntax::AST::Printer.new.print(ast, io)
  io.to_s
end

private class AstParityVisitRecorder
  include Regex::Syntax::AST::Visitor

  getter events = [] of String

  def start : Nil
    @events << "start"
  end

  def finish : Array(String)
    @events << "finish"
    @events
  end

  def visit_pre(node : Regex::Syntax::AST::Node) : Nil
    @events << "pre:#{node.class.name.split("::").last}"
  end

  def visit_post(node : Regex::Syntax::AST::Node) : Nil
    @events << "post:#{node.class.name.split("::").last}"
  end

  def visit_alternation_in : Nil
    @events << "alt:in"
  end

  def visit_concat_in : Nil
    @events << "concat:in"
  end

  def visit_class_set_item_pre(node : Regex::Syntax::AST::ClassSetItem) : Nil
    @events << "class-item-pre:#{node.kind}"
  end

  def visit_class_set_item_post(node : Regex::Syntax::AST::ClassSetItem) : Nil
    @events << "class-item-post:#{node.kind}"
  end

  def visit_class_set_binary_op_pre(node : Regex::Syntax::AST::ClassSetBinaryOp) : Nil
    @events << "class-op-pre:#{node.kind}"
  end

  def visit_class_set_binary_op_post(node : Regex::Syntax::AST::ClassSetBinaryOp) : Nil
    @events << "class-op-post:#{node.kind}"
  end

  def visit_class_set_binary_op_in(node : Regex::Syntax::AST::ClassSetBinaryOp) : Nil
    @events << "class-op-in:#{node.kind}"
  end
end

describe "AST printer and visitor parity" do
  it "prints literals, dot, concatenation, and alternation" do
    print_ast("a").should eq("a")
    print_ast(%q(\[)).should eq(%q(\[))
    print_ast(".").should eq(".")
    print_ast("ab").should eq("ab")
    print_ast("a|b|c").should eq("a|b|c")
  end

  it "prints assertions and repetitions" do
    print_ast("^").should eq("^")
    print_ast(%q(\A)).should eq(%q(\A))
    print_ast(%q(\b{start-half})).should eq(%q(\b{start-half}))
    print_ast(%q(\<)).should eq(%q(\<))
    print_ast("a??").should eq("a??")
    print_ast("a{5,10}?").should eq("a{5,10}?")
  end

  it "prints flags, groups, and classes" do
    print_ast("(?siUmux)").should eq("(?siUmux)")
    print_ast("(?P<foo>a)").should eq("(?P<foo>a)")
    print_ast("(?:a)").should eq("(?:a)")
    print_ast(%q(\D)).should eq(%q(\D))
    print_ast("[[:^space:]]").should eq("[[:^space:]]")
    print_ast(%q(\P{sc:Greek})).should eq(%q(\P{sc:Greek}))
    print_ast("[a-z&&m-n]").should eq("[a-z&&m-n]")
  end

  it "visits AST nodes and class-set operators in depth-first order" do
    ast = Regex::Syntax::AstParser.new.parse("[a&&[b-c]]|d")
    events = Regex::Syntax::AST.visit(ast, AstParityVisitRecorder.new)

    events.should eq([
      "start",
      "pre:Alternation",
      "pre:ClassBracketed",
      "class-op-pre:Intersection",
      "class-item-pre:Literal",
      "class-item-post:Literal",
      "class-op-in:Intersection",
      "class-item-pre:Bracketed",
      "class-item-pre:Range",
      "class-item-post:Range",
      "class-item-post:Bracketed",
      "class-op-post:Intersection",
      "post:ClassBracketed",
      "alt:in",
      "pre:Literal",
      "post:Literal",
      "post:Alternation",
      "finish",
    ])
  end
end
