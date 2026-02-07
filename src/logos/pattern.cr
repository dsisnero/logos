require "./pattern/parser"
require "regex-syntax"

module Logos
  # Abstract syntax tree for regex patterns (deprecated, use Regex::Syntax::Hir instead)
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
    getter hir : ::Regex::Syntax::Hir::Hir?
    getter bytes : Bytes? # For literal patterns (optional optimization)

    def initialize(literal : Bool, @source : String, hir : ::Regex::Syntax::Hir::Hir? = nil, @bytes : Bytes? = nil)
      @literal = literal
      @hir = hir

      if literal
        raise "Literal pattern must have bytes" if @bytes.nil?
        # Create HIR literal from bytes if not provided
        @hir ||= ::Regex::Syntax::Hir::Hir.literal(@bytes.as(Bytes))
      else
        raise "Regex pattern must have HIR" if @hir.nil?
      end
    end

    # Create pattern from literal string
    def self.compile_literal(source : String) : self
      bytes = source.to_slice
      hir = ::Regex::Syntax::Hir::Hir.literal(bytes)
      Pattern.new(true, source, hir, bytes)
    end

    # Create pattern from regex string
    def self.compile_regex(source : String, unicode : Bool = true, ignore_case : Bool = false) : self
      hir = ::Regex::Syntax.parse(source, unicode: unicode, ignore_case: ignore_case)
      Pattern.new(false, source, hir)
    end

    # Calculate priority/complexity for disambiguation
    def priority : Int32
      @hir.try(&.complexity) || 0
    end

    # Check for problematic patterns like greedy .* or .+
    def check_for_greedy_all : Bool
      @hir.try(&.has_greedy_all?) || false
    end
  end
end
