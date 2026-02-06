require "./pattern/parser"

module Logos
  # Abstract syntax tree for regex patterns
  module PatternAST
    # Base class for all pattern AST nodes
    abstract class Node
    end

    # Empty pattern (matches nothing)
    class Empty < Node
    end

    # Literal byte or character sequence
    class Literal < Node
      getter bytes : Bytes

      def initialize(@bytes : Bytes)
      end

      # Create from string
      def self.from_string(str : String) : self
        new(str.to_slice)
      end

      # Create from byte array
      def self.from_bytes(bytes : Array(UInt8)) : self
        new(Bytes.new(bytes.size) { |i| bytes[i] })
      end
    end

    # Character class (e.g., [a-z], [^a-z], \d, \w, .)
    class CharClass < Node
      enum Kind
        AnyChar # .
        AnyByte # . in byte mode
        AnyCharExceptLF
        AnyByteExceptLF
        AnyCharExceptCRLF
        AnyByteExceptCRLF
        Range        # [a-z]
        NegatedRange # [^a-z]
        Digit        # \d
        NonDigit     # \D
        Word         # \w
        NonWord      # \W
        Space        # \s
        NonSpace     # \S
      end

      getter kind : Kind
      getter ranges : Array(Range(Char, Char))? # For Range/NegatedRange kinds

      def initialize(@kind : Kind, @ranges : Array(Range(Char, Char))? = nil)
      end
    end

    # Concatenation of patterns (a followed by b)
    class Concat < Node
      getter children : Array(Node)

      def initialize(children : Array(Node))
        @children = children
      end

      def self.new(*children : Node)
        new(children.to_a.map(&.as(Node)))
      end
    end

    # Alternation of patterns (a or b)
    class Alternation < Node
      getter children : Array(Node)

      def initialize(children : Array(Node))
        @children = children
      end

      def self.new(*children : Node)
        new(children.to_a.map(&.as(Node)))
      end
    end

    # Repetition (a*, a+, a{n}, a{n,}, a{n,m})
    class Repetition < Node
      getter child : Node
      getter min : Int32
      getter max : Int32? # nil means unbounded
      getter? greedy : Bool

      def initialize(@child : Node, @min : Int32, @max : Int32?, greedy : Bool = true)
        @greedy = greedy
      end
    end

    # Lookahead/lookbehind assertions
    class Look < Node
      enum Kind
        Start           # ^
        End             # $
        WordBoundary    # \b
        NonWordBoundary # \B
      end

      getter kind : Kind

      def initialize(@kind : Kind)
      end
    end

    # Capture group (for callbacks)
    class Capture < Node
      getter child : Node
      getter index : Int32 # Capture group index

      def initialize(@child : Node, @index : Int32)
      end
    end
  end

  # Compiled pattern with metadata
  class Pattern
    getter? literal : Bool
    getter source : String
    getter ast : PatternAST::Node?
    getter bytes : Bytes? # For literal patterns

    def initialize(literal : Bool, @source : String, @ast : PatternAST::Node? = nil, @bytes : Bytes? = nil)
      @literal = literal
      raise "Literal pattern must have bytes" if literal && @bytes.nil?
      raise "Regex pattern must have ast" if !literal && @ast.nil?
    end

    # Create pattern from literal string
    def self.compile_literal(source : String) : self
      bytes = source.to_slice
      Pattern.new(true, source, nil, bytes)
    end

    # Create pattern from regex string
    def self.compile_regex(source : String, unicode : Bool = true, ignore_case : Bool = false) : self
      parser = PatternParser::Parser.new(source, unicode, ignore_case)
      ast = parser.parse
      Pattern.new(false, source, ast)
    end

    # Calculate priority/complexity for disambiguation
    def priority : Int32
      return bytes.try(&.size) || 0 if literal?
      calculate_complexity(ast.as(PatternAST::Node))
    end

    private def calculate_complexity(node : PatternAST::Node) : Int32
      case node
      when PatternAST::Empty
        0
      when PatternAST::Literal
        # Weight literals by character count (2 per char for unicode, 2 per byte for bytes)
        node.bytes.size * 2
      when PatternAST::CharClass
        2 # Fixed cost for character classes
      when PatternAST::Look
        0 # Lookarounds don't consume characters
      when PatternAST::Repetition
        node.min * calculate_complexity(node.child)
      when PatternAST::Capture
        calculate_complexity(node.child)
      when PatternAST::Concat
        node.children.sum { |child| calculate_complexity(child) }
      when PatternAST::Alternation
        node.children.min_of? { |child| calculate_complexity(child) } || 0
      else
        0
      end
    end

    # Check for problematic patterns like greedy .* or .+
    def check_for_greedy_all : Bool
      return false if literal?
      has_greedy_all(ast.as(PatternAST::Node))
    end

    private def has_greedy_all(node : PatternAST::Node) : Bool
      case node
      when PatternAST::Repetition
        # Check if it's a dot repetition
        is_dot = node.child.is_a?(PatternAST::CharClass) &&
                 node.child.as(PatternAST::CharClass).kind.in?([
                   PatternAST::CharClass::Kind::AnyChar,
                   PatternAST::CharClass::Kind::AnyByte,
                   PatternAST::CharClass::Kind::AnyCharExceptLF,
                   PatternAST::CharClass::Kind::AnyByteExceptLF,
                   PatternAST::CharClass::Kind::AnyCharExceptCRLF,
                   PatternAST::CharClass::Kind::AnyByteExceptCRLF,
                 ])
        is_unbounded = node.max.nil?
        is_greedy = node.greedy?

        is_dot && is_unbounded && is_greedy
      when PatternAST::Capture
        has_greedy_all(node.child)
      when PatternAST::Concat
        node.children.any? { |child| has_greedy_all(child) }
      when PatternAST::Alternation
        node.children.any? { |child| has_greedy_all(child) }
      else
        false
      end
    end
  end
end
