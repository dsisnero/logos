require "../spec_helper"

describe Logos::Pattern do
  describe ".compile_literal" do
    it "creates literal pattern from string" do
      pattern = Logos::Pattern.compile_literal("hello")
      pattern.should be_a(Logos::Pattern)
      pattern.literal?.should be_true
      pattern.source.should eq("hello")
      pattern.bytes.should eq("hello".to_slice)
      pattern.hir.should be_a(Regex::Syntax::Hir::Hir)
      pattern.hir.as(Regex::Syntax::Hir::Hir).node.should be_a(Regex::Syntax::Hir::Literal)
    end

    it "calculates priority based on byte length" do
      pattern = Logos::Pattern.compile_literal("hello")
      pattern.priority.should eq(10) # 5 bytes * 2 (HIR literal complexity)
    end

    it "does not have greedy all" do
      pattern = Logos::Pattern.compile_literal("hello")
      pattern.check_for_greedy_all.should be_false
    end
  end

  describe ".compile_regex" do
    it "creates regex pattern placeholder" do
      pattern = Logos::Pattern.compile_regex("a+")
      pattern.should be_a(Logos::Pattern)
      pattern.literal?.should be_false
      pattern.source.should eq("a+")
      pattern.hir.should be_a(Regex::Syntax::Hir::Hir)
    end

    pending "parses actual regex patterns" do
      # TODO: Implement regex parsing
    end
  end

  describe "AST complexity calculation" do
    it "calculates complexity for empty" do
      hir = Regex::Syntax::Hir::Hir.new(Regex::Syntax::Hir::Empty.new)
      pattern = Logos::Pattern.new(false, "test", hir)
      pattern.priority.should eq(0)
    end

    it "calculates complexity for literal" do
      hir = Regex::Syntax::Hir::Hir.literal("abc".to_slice)
      pattern = Logos::Pattern.new(false, "test", hir)
      pattern.priority.should eq(6) # 3 bytes * 2
    end

    it "calculates complexity for char class" do
      hir = Regex::Syntax::Hir::Hir.dot(Regex::Syntax::Hir::Dot::AnyChar)
      pattern = Logos::Pattern.new(false, "test", hir)
      pattern.priority.should eq(2)
    end

    it "calculates complexity for concat" do
      child1 = Regex::Syntax::Hir::Hir.literal("a".to_slice).node
      child2 = Regex::Syntax::Hir::Hir.dot(Regex::Syntax::Hir::Dot::AnyChar).node
      hir = Regex::Syntax::Hir::Hir.new(Regex::Syntax::Hir::Concat.new([child1, child2]))
      pattern = Logos::Pattern.new(false, "test", hir)
      pattern.priority.should eq(4) # 2 + 2
    end

    it "calculates complexity for alternation" do
      child1 = Regex::Syntax::Hir::Hir.literal("ab".to_slice).node
      child2 = Regex::Syntax::Hir::Hir.literal("c".to_slice).node
      hir = Regex::Syntax::Hir::Hir.new(Regex::Syntax::Hir::Alternation.new([child1, child2]))
      pattern = Logos::Pattern.new(false, "test", hir)
      pattern.priority.should eq(2) # min of 4 and 2
    end

    it "calculates complexity for repetition" do
      child = Regex::Syntax::Hir::Hir.literal("a".to_slice).node
      hir = Regex::Syntax::Hir::Hir.new(Regex::Syntax::Hir::Repetition.new(child, 3, nil))
      pattern = Logos::Pattern.new(false, "test", hir)
      pattern.priority.should eq(6) # 3 * 2
    end
  end

  describe "regex parsing" do
    it "parses literal regex" do
      pattern = Logos::Pattern.compile_regex("hello")
      pattern.should be_a(Logos::Pattern)
      pattern.literal?.should be_false
      pattern.source.should eq("hello")
      # Should parse as concatenation of literals (or single literal for efficiency)
      node = pattern.hir.as(Regex::Syntax::Hir::Hir).node
      case node
      when Regex::Syntax::Hir::Concat
        concat = node.as(Regex::Syntax::Hir::Concat)
        concat.children.all?(Regex::Syntax::Hir::Literal).should be_true
      when Regex::Syntax::Hir::Literal
        literal = node.as(Regex::Syntax::Hir::Literal)
        String.new(literal.bytes).should eq("hello")
      else
        fail "Expected Concat or Literal, got #{node.class}"
      end
    end

    it "parses dot" do
      pattern = Logos::Pattern.compile_regex(".")
      pattern.hir.as(Regex::Syntax::Hir::Hir).node.should be_a(Regex::Syntax::Hir::CharClass)
      # Note: In HIR, dot is represented as CharClass with empty intervals
      # (implementation detail). We'll just verify it's a CharClass.
    end

    it "parses character class" do
      pattern = Logos::Pattern.compile_regex("[abc]")
      node = pattern.hir.as(Regex::Syntax::Hir::Hir).node
      node.should be_a(Regex::Syntax::Hir::CharClass)
      char_class = node.as(Regex::Syntax::Hir::CharClass)
      char_class.intervals.should_not be_empty
    end

    it "parses repetition" do
      pattern = Logos::Pattern.compile_regex("a+")
      node = pattern.hir.as(Regex::Syntax::Hir::Hir).node
      node.should be_a(Regex::Syntax::Hir::Repetition)
      repetition = node.as(Regex::Syntax::Hir::Repetition)
      repetition.min.should eq(1)
      repetition.max.should be_nil
      repetition.greedy.should be_true
    end

    it "parses alternation" do
      pattern = Logos::Pattern.compile_regex("a|b")
      node = pattern.hir.as(Regex::Syntax::Hir::Hir).node
      node.should be_a(Regex::Syntax::Hir::Alternation)
      alternation = node.as(Regex::Syntax::Hir::Alternation)
      alternation.children.size.should eq(2)
    end

    it "parses group" do
      pattern = Logos::Pattern.compile_regex("(ab)")
      # Group is captured as Capture node
      node = pattern.hir.as(Regex::Syntax::Hir::Hir).node
      node.should be_a(Regex::Syntax::Hir::Capture)
      capture = node.as(Regex::Syntax::Hir::Capture)
      case capture.sub
      when Regex::Syntax::Hir::Concat
        # Group contains concatenation
        concat = capture.sub.as(Regex::Syntax::Hir::Concat)
        concat.children.all?(Regex::Syntax::Hir::Literal).should be_true
      when Regex::Syntax::Hir::Literal
        # Group contains single literal
        literal = capture.sub.as(Regex::Syntax::Hir::Literal)
        String.new(literal.bytes).should eq("ab")
      else
        fail "Expected Concat or Literal, got #{capture.sub.class}"
      end
      # Actually group should be captured, but for now we just parse contents
    end

    it "parses escaped characters" do
      pattern = Logos::Pattern.compile_regex("\\.")
      node = pattern.hir.as(Regex::Syntax::Hir::Hir).node
      node.should be_a(Regex::Syntax::Hir::Literal)
      literal = node.as(Regex::Syntax::Hir::Literal)
      literal.bytes.should eq(".".to_slice)
    end

    it "parses shorthand classes" do
      pattern = Logos::Pattern.compile_regex("\\d")
      pattern.hir.as(Regex::Syntax::Hir::Hir).node.should be_a(Regex::Syntax::Hir::CharClass)
      # Note: In HIR, \d is represented as CharClass with digit intervals
    end
  end
end
