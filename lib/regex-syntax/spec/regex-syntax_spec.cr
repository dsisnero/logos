require "./spec_helper"

describe Regex::Syntax do
  it "can be required" do
    # Just test that the module exists
    Regex::Syntax.should_not be_nil
  end

  it "has version constant" do
    Regex::Syntax::VERSION.should be_a(String)
  end

  it "defines Parser class" do
    parser = Regex::Syntax::Parser.new
    parser.should be_a(Regex::Syntax::Parser)
  end

  describe "parsing" do
    it "parses literal string" do
      hir = Regex::Syntax.parse("hello")
      hir.should be_a(Regex::Syntax::Hir::Hir)
      hir.node.should be_a(Regex::Syntax::Hir::Literal)
      literal = hir.node.as(Regex::Syntax::Hir::Literal)
      String.new(literal.bytes).should eq("hello")
    end

    it "parses alternation" do
      hir = Regex::Syntax.parse("a|b")
      hir.node.should be_a(Regex::Syntax::Hir::Alternation)
      alt = hir.node.as(Regex::Syntax::Hir::Alternation)
      alt.children.size.should eq(2)
      alt.children[0].should be_a(Regex::Syntax::Hir::Literal)
      alt.children[1].should be_a(Regex::Syntax::Hir::Literal)
    end

    it "parses concatenation" do
      hir = Regex::Syntax.parse("ab")
      case hir.node
      when Regex::Syntax::Hir::Concat
        concat = hir.node.as(Regex::Syntax::Hir::Concat)
        concat.children.size.should eq(2)
        concat.children[0].should be_a(Regex::Syntax::Hir::Literal)
        concat.children[1].should be_a(Regex::Syntax::Hir::Literal)
      when Regex::Syntax::Hir::Literal
        literal = hir.node.as(Regex::Syntax::Hir::Literal)
        String.new(literal.bytes).should eq("ab")
      else
        fail "Expected Concat or Literal, got #{hir.node.class}"
      end
    end

    it "parses dot" do
      hir = Regex::Syntax.parse(".")
      hir.node.should be_a(Regex::Syntax::Hir::DotNode)
      dot_node = hir.node.as(Regex::Syntax::Hir::DotNode)
      dot_node.kind.should eq(Regex::Syntax::Hir::Dot::AnyChar)
    end

    it "parses character class" do
      hir = Regex::Syntax.parse("[a-z]")
      case hir.node
      when Regex::Syntax::Hir::CharClass
        char_class = hir.node.as(Regex::Syntax::Hir::CharClass)
        char_class.intervals.should eq([('a'.ord.to_u8)..('z'.ord.to_u8)])
      when Regex::Syntax::Hir::UnicodeClass
        unicode_class = hir.node.as(Regex::Syntax::Hir::UnicodeClass)
        unicode_class.intervals.should eq([('a'.ord.to_u32)..('z'.ord.to_u32)])
      else
        fail "Expected CharClass or UnicodeClass, got #{hir.node.class}"
      end
    end

    it "parses repetition *" do
      hir = Regex::Syntax.parse("a*")
      hir.node.should be_a(Regex::Syntax::Hir::Repetition)
      rep = hir.node.as(Regex::Syntax::Hir::Repetition)
      rep.min.should eq(0)
      rep.max.should be_nil
      rep.sub.should be_a(Regex::Syntax::Hir::Literal)
    end

    it "parses repetition +" do
      hir = Regex::Syntax.parse("a+")
      hir.node.should be_a(Regex::Syntax::Hir::Repetition)
      rep = hir.node.as(Regex::Syntax::Hir::Repetition)
      rep.min.should eq(1)
      rep.max.should be_nil
    end

    it "parses repetition ?" do
      hir = Regex::Syntax.parse("a?")
      hir.node.should be_a(Regex::Syntax::Hir::Repetition)
      rep = hir.node.as(Regex::Syntax::Hir::Repetition)
      rep.min.should eq(0)
      rep.max.should eq(1)
    end

    it "parses escape sequences" do
      hir = Regex::Syntax.parse("\\n")
      hir.node.should be_a(Regex::Syntax::Hir::Literal)
      literal = hir.node.as(Regex::Syntax::Hir::Literal)
      String.new(literal.bytes).should eq("\n")
    end

    it "parses word boundary" do
      hir = Regex::Syntax.parse("\\b")
      hir.node.should be_a(Regex::Syntax::Hir::Look)
      look = hir.node.as(Regex::Syntax::Hir::Look)
      look.kind.should eq(Regex::Syntax::Hir::Look::Kind::WordBoundary)
    end

    it "parses start anchor ^" do
      hir = Regex::Syntax.parse("^")
      hir.node.should be_a(Regex::Syntax::Hir::Look)
      look = hir.node.as(Regex::Syntax::Hir::Look)
      look.kind.should eq(Regex::Syntax::Hir::Look::Kind::Start)
    end

    it "parses end anchor $" do
      hir = Regex::Syntax.parse("$")
      hir.node.should be_a(Regex::Syntax::Hir::Look)
      look = hir.node.as(Regex::Syntax::Hir::Look)
      look.kind.should eq(Regex::Syntax::Hir::Look::Kind::End)
    end

    it "parses non-capturing group (?:...)" do
      hir = Regex::Syntax.parse("(?:ab)")
      # Non-capturing group should parse child expression
      # For now, it just returns the child directly
      case hir.node
      when Regex::Syntax::Hir::Concat
        concat = hir.node.as(Regex::Syntax::Hir::Concat)
        concat.children.size.should eq(2)
        concat.children[0].should be_a(Regex::Syntax::Hir::Literal)
        concat.children[1].should be_a(Regex::Syntax::Hir::Literal)
      when Regex::Syntax::Hir::Literal
        literal = hir.node.as(Regex::Syntax::Hir::Literal)
        String.new(literal.bytes).should eq("ab")
      else
        fail "Expected Concat or Literal, got #{hir.node.class}"
      end
    end

    it "parses flag group (?i:...)" do
      hir = Regex::Syntax.parse("(?i:ab)")
      hir.node.should be_a(Regex::Syntax::Hir::Concat)
      concat = hir.node.as(Regex::Syntax::Hir::Concat)
      concat.children.size.should eq(2)
      concat.children[0].should be_a(Regex::Syntax::Hir::CharClass)
      concat.children[1].should be_a(Regex::Syntax::Hir::CharClass)
    end

    it "parses global inline flags (?i) for following expression" do
      hir = Regex::Syntax.parse("(?i)ab")
      hir.node.should be_a(Regex::Syntax::Hir::Concat)
      concat = hir.node.as(Regex::Syntax::Hir::Concat)
      concat.children.size.should eq(2)
      concat.children[0].should be_a(Regex::Syntax::Hir::CharClass)
      concat.children[1].should be_a(Regex::Syntax::Hir::CharClass)
    end

    it "rejects unsupported look-ahead groups" do
      expect_raises(Regex::Syntax::ParseError, /look-ahead/) do
        Regex::Syntax.parse("(?=a)b")
      end
    end

    it "computes whether a pattern can match the empty string" do
      Regex::Syntax.parse("a+").can_match_empty?.should be_false
      Regex::Syntax.parse("a*").can_match_empty?.should be_true
      Regex::Syntax.parse("(?:a|)").can_match_empty?.should be_true
    end
  end
end
