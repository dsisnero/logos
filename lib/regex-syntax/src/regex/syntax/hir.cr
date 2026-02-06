module Regex::Syntax::Hir
  # A type describing the different flavors of `.`
  enum Dot
    # Matches the UTF-8 encoding of any Unicode scalar value
    AnyChar
    # Matches any byte value
    AnyByte
    # Matches the UTF-8 encoding of any Unicode scalar value except for \n
    AnyCharExceptLF
    # Matches any byte value except for \n
    AnyByteExceptLF
    # Matches the UTF-8 encoding of any Unicode scalar value except for \r and \n
    AnyCharExceptCRLF
    # Matches any byte value except for \r and \n
    AnyByteExceptCRLF
  end

  # Base class for all HIR nodes
  abstract class Node
    # Calculate complexity/priority for disambiguation
    abstract def complexity : Int32

    # Check if contains greedy .* or .+
    abstract def has_greedy_all? : Bool
  end

  # Empty pattern (matches nothing)
  class Empty < Node
    def complexity : Int32
      0
    end

    def has_greedy_all? : Bool
      false
    end
  end

  # Literal byte sequence
  class Literal < Node
    getter bytes : Bytes

    def initialize(@bytes : Bytes)
    end

    def complexity : Int32
      bytes.size * 2
    end

    def has_greedy_all? : Bool
      false
    end
  end

  # Character class
  class CharClass < Node
    # TODO: Implement character classes
    getter negated : Bool
    getter intervals : Array(Range(UInt8, UInt8))

    def initialize(@negated : Bool = false, @intervals : Array(Range(UInt8, UInt8)) = [] of Range(UInt8, UInt8))
    end

    def complexity : Int32
      2
    end

    def has_greedy_all? : Bool
      false
    end
  end

  # Look-around assertion
  class Look < Node
    enum Kind
      Start                # ^
      End                  # $
      StartText            # \A
      EndText              # \z
      EndTextWithNewline   # \Z
      WordBoundary         # \b
      NonWordBoundary      # \B
    end

    getter kind : Kind

    def initialize(@kind : Kind)
    end

    def complexity : Int32
      0
    end

    def has_greedy_all? : Bool
      false
    end
  end

  # Repetition
  class Repetition < Node
    getter sub : Node
    getter min : Int32
    getter max : Int32?
    getter greedy : Bool

    def initialize(@sub : Node, @min : Int32, @max : Int32?, @greedy : Bool = true)
    end

    def complexity : Int32
      min * sub.complexity
    end

    def has_greedy_all? : Bool
      # TODO: Implement proper dot detection
      false
    end
  end

  # Capture group
  class Capture < Node
    getter sub : Node
    getter index : Int32

    def initialize(@sub : Node, @index : Int32)
    end

    def complexity : Int32
      sub.complexity
    end

    def has_greedy_all? : Bool
      sub.has_greedy_all?
    end
  end

  # Concatenation
  class Concat < Node
    getter children : Array(Node)

    def initialize(@children : Array(Node))
    end

    def complexity : Int32
      children.sum { |child| child.complexity }
    end

    def has_greedy_all? : Bool
      children.any? { |child| child.has_greedy_all? }
    end
  end

  # Alternation
  class Alternation < Node
    getter children : Array(Node)

    def initialize(@children : Array(Node))
    end

    def complexity : Int32
      children.min_of? { |child| child.complexity } || 0
    end

    def has_greedy_all? : Bool
      children.any? { |child| child.has_greedy_all? }
    end
  end

  # High-level intermediate representation for a regular expression
  class Hir < Node
    getter node : Node

    def initialize(@node : Node)
    end

    # Create a dot expression
    def self.dot(dot : Dot) : Hir
      # TODO: Implement proper dot to class conversion
      Hir.new(CharClass.new)
    end

    # Create a literal expression
    def self.literal(bytes : Bytes) : Hir
      Hir.new(Literal.new(bytes))
    end

    def complexity : Int32
      node.complexity
    end

    def has_greedy_all? : Bool
      node.has_greedy_all?
    end
  end
end