require "../spec_helper"

describe Logos::Pattern do
  describe ".compile_literal" do
    it "creates literal pattern from string" do
      pattern = Logos::Pattern.compile_literal("hello")
      pattern.should be_a(Logos::Pattern)
      pattern.literal?.should be_true
      pattern.source.should eq("hello")
      pattern.bytes.should eq("hello".to_slice)
      pattern.ast.should be_nil
    end

    it "calculates priority based on byte length" do
      pattern = Logos::Pattern.compile_literal("hello")
      pattern.priority.should eq(5) # 5 bytes * 1 (but we use size, not *2?)
      # Actually priority returns bytes.size for literals
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
      pattern.ast.should be_a(Logos::PatternAST::Node)
    end

    pending "parses actual regex patterns" do
      # TODO: Implement regex parsing
    end
  end

  describe "AST complexity calculation" do
    it "calculates complexity for empty" do
      node = Logos::PatternAST::Empty.new
      # Need a way to test private method, or test through pattern
      pattern = Logos::Pattern.new(false, "test", node)
      pattern.priority.should eq(0)
    end

    it "calculates complexity for literal" do
      node = Logos::PatternAST::Literal.from_string("abc")
      pattern = Logos::Pattern.new(false, "test", node)
      pattern.priority.should eq(6) # 3 bytes * 2
    end

    it "calculates complexity for char class" do
      node = Logos::PatternAST::CharClass.new(Logos::PatternAST::CharClass::Kind::AnyChar)
      pattern = Logos::Pattern.new(false, "test", node)
      pattern.priority.should eq(2)
    end

    it "calculates complexity for concat" do
      child1 = Logos::PatternAST::Literal.from_string("a")
      child2 = Logos::PatternAST::CharClass.new(Logos::PatternAST::CharClass::Kind::AnyChar)
      node = Logos::PatternAST::Concat.new(child1, child2)
      pattern = Logos::Pattern.new(false, "test", node)
      pattern.priority.should eq(4) # 2 + 2
    end

    it "calculates complexity for alternation" do
      child1 = Logos::PatternAST::Literal.from_string("ab") # 4
      child2 = Logos::PatternAST::Literal.from_string("c")  # 2
      node = Logos::PatternAST::Alternation.new(child1, child2)
      pattern = Logos::Pattern.new(false, "test", node)
      pattern.priority.should eq(2) # min of 4 and 2
    end

    it "calculates complexity for repetition" do
      child = Logos::PatternAST::Literal.from_string("a")     # 2
      node = Logos::PatternAST::Repetition.new(child, 3, nil) # a{3,}
      pattern = Logos::Pattern.new(false, "test", node)
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
      case pattern.ast
      when Logos::PatternAST::Concat
        concat = pattern.ast.as(Logos::PatternAST::Concat)
        concat.children.all?(Logos::PatternAST::Literal).should be_true
      when Logos::PatternAST::Literal
        literal = pattern.ast.as(Logos::PatternAST::Literal)
        String.new(literal.bytes).should eq("hello")
      else
        fail "Expected Concat or Literal, got #{pattern.ast.class}"
      end
    end

    it "parses dot" do
      pattern = Logos::Pattern.compile_regex(".")
      pattern.ast.should be_a(Logos::PatternAST::CharClass)
      char_class = pattern.ast.as(Logos::PatternAST::CharClass)
      char_class.kind.should eq(Logos::PatternAST::CharClass::Kind::AnyChar)
    end

    it "parses character class" do
      pattern = Logos::Pattern.compile_regex("[abc]")
      pattern.ast.should be_a(Logos::PatternAST::CharClass)
      char_class = pattern.ast.as(Logos::PatternAST::CharClass)
      char_class.kind.should eq(Logos::PatternAST::CharClass::Kind::Range)
      char_class.ranges.should_not be_nil
    end

    it "parses repetition" do
      pattern = Logos::Pattern.compile_regex("a+")
      pattern.ast.should be_a(Logos::PatternAST::Repetition)
      repetition = pattern.ast.as(Logos::PatternAST::Repetition)
      repetition.min.should eq(1)
      repetition.max.should be_nil
      repetition.greedy?.should be_true
    end

    it "parses alternation" do
      pattern = Logos::Pattern.compile_regex("a|b")
      pattern.ast.should be_a(Logos::PatternAST::Alternation)
      alternation = pattern.ast.as(Logos::PatternAST::Alternation)
      alternation.children.size.should eq(2)
    end

    it "parses group" do
      pattern = Logos::Pattern.compile_regex("(ab)")
      # Group is just a container - contents could be Concat or Literal
      case pattern.ast
      when Logos::PatternAST::Concat
        # Group contains concatenation
        concat = pattern.ast.as(Logos::PatternAST::Concat)
        concat.children.all?(Logos::PatternAST::Literal).should be_true
      when Logos::PatternAST::Literal
        # Group contains single literal
        literal = pattern.ast.as(Logos::PatternAST::Literal)
        String.new(literal.bytes).should eq("ab")
      else
        fail "Expected Concat or Literal, got #{pattern.ast.class}"
      end
      # Actually group should be captured, but for now we just parse contents
    end

    it "parses escaped characters" do
      pattern = Logos::Pattern.compile_regex("\\.")
      pattern.ast.should be_a(Logos::PatternAST::Literal)
      literal = pattern.ast.as(Logos::PatternAST::Literal)
      literal.bytes.should eq(".".to_slice)
    end

    it "parses shorthand classes" do
      pattern = Logos::Pattern.compile_regex("\\d")
      pattern.ast.should be_a(Logos::PatternAST::CharClass)
      char_class = pattern.ast.as(Logos::PatternAST::CharClass)
      char_class.kind.should eq(Logos::PatternAST::CharClass::Kind::Digit)
    end
  end
end
