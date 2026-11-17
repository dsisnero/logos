require "./pattern/parser"
require "regex-syntax"
require "regex-automata"

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
      hir = ::Regex::Syntax.parse(source, unicode: unicode, utf8: unicode, ignore_case: ignore_case)
      Pattern.new(false, source, hir)
    end

    # Apply folding while preserving token metacharacters as literal text.
    def self.literal_hir(source : String, unicode : Bool, ignore_case : Bool) : ::Regex::Syntax::Hir::Hir
      return ::Regex::Syntax::Hir::Hir.literal(source.to_slice) unless ignore_case
      if unicode
        escaped = ::Regex::Syntax.escape(regex_source(source, unicode: true))
        regex_hir(escaped, unicode: true, ignore_case: true)
      else
        hir = ::Regex::Syntax::Hir::Hir.literal(source.to_slice)
        ::Regex::Syntax::Hir.case_fold_ascii(hir)
      end
    end

    # Parse case flags in context. UTF-8 acceptance is checked on the completed HIR.
    def self.regex_hir(source : String, unicode : Bool, ignore_case : Bool = false,
                       subpatterns : Hash(String, String)? = nil) : ::Regex::Syntax::Hir::Hir
      source = regex_source(source, unicode)
      source = substitute_subpatterns(source, subpatterns) if subpatterns
      ::Regex::Syntax.parse(source, unicode: unicode, utf8: false, ignore_case: ignore_case)
    end

    # Match Rust's handling of a byte string used as a regular expression.
    private def self.regex_source(source : String, unicode : Bool) : String
      return source if source.valid_encoding?
      raise "UTF-8 regex #{source.inspect} contains byte-oriented text" if unicode

      String.build do |io|
        source.each_byte do |byte|
          if byte < 0x80
            io.write_byte(byte)
          else
            io << "\\x" << byte.to_s(16).rjust(2, '0')
          end
        end
      end
    end

    # Validate a rule against the lexer's source type, independently of its syntax.
    def self.validate_utf8(hir : ::Regex::Syntax::Hir::Hir, source : String) : Nil
      unless hir.utf8?
        raise "UTF-8 mode is enabled, but byte-oriented pattern #{source.inspect} can match invalid UTF-8. Set utf8: false to allow byte-oriented matching."
      end
    end

    # Expand and validate definitions in order, retaining each definition's encoding.
    def self.expand_subpatterns(definitions : Enumerable({String, String, Bool}), utf8 : Bool) : Hash(String, String)
      expanded = {} of String => String
      definitions.each do |name, pattern, unicode|
        raise "Subpattern #{name.inspect} already exists" if expanded.has_key?(name)
        flags = unicode ? "u" : "-u"
        source = substitute_subpatterns(regex_source(pattern, unicode), expanded)
        wrapped = "(?#{flags}:#{source})"
        hir = regex_hir(wrapped, unicode: unicode)
        validate_utf8(hir, pattern) if utf8
        expanded[name] = wrapped
      end
      expanded
    end

    # Replace complete named references with their already-expanded groups.
    def self.substitute_subpatterns(pattern : String, expanded : Hash(String, String)) : String
      return pattern unless pattern.includes?("(?&")

      pattern.gsub(/\(\?&([a-zA-Z0-9_]+)\)/) do |_, match|
        name = match[1]
        expanded[name]? || raise "unknown subpattern reference: #{name}"
      end
    end

    # Calculate priority/complexity for disambiguation
    def priority : Int32
      return @source.bytesize * 2 if literal?
      @hir.try { |hir| self.class.regex_priority(hir.node) } || 0
    end

    # Weight regex literals by Unicode scalars if valid UTF-8, or by bytes.
    def self.regex_priority(node : ::Regex::Syntax::Hir::Node) : Int32
      case node
      when ::Regex::Syntax::Hir::Literal
        text = String.new(node.bytes)
        (text.valid_encoding? ? text.size : node.bytes.size) * 2
      when ::Regex::Syntax::Hir::Capture
        regex_priority(node.sub)
      when ::Regex::Syntax::Hir::Repetition
        {Int32::MAX.to_i64, node.min.to_i64 * regex_priority(node.sub)}.min.to_i32
      when ::Regex::Syntax::Hir::Concat
        {Int32::MAX.to_i64, node.children.sum { |child| regex_priority(child).to_i64 }}.min.to_i32
      when ::Regex::Syntax::Hir::Alternation
        node.children.min_of? { |child| regex_priority(child) } || 0
      else
        node.complexity
      end
    end

    # Check the winners at each accepting state, after higher priorities
    # have masked any lower-priority overlaps.
    def self.validate_priorities(dfa : ::Regex::Automata::DFA::DFA, priorities : Array(Int32), explicit : Array(Bool), patterns : Array(String), variants : Array(String)) : Nil
      dfa.states.each do |state|
        matches = state.match
        next if matches.size < 2

        best = matches.max_of { |id| priorities[id.to_i] }
        winners = matches.select { |id| priorities[id.to_i] == best }
        next unless ambiguous_winners?(winners, explicit, variants)

        labels = winners.map { |id| "#{patterns[id.to_i]} (#{variants[id.to_i]})" }
        raise "Patterns #{labels.join(", ")} can match simultaneously at priority #{best}."
      end
    end

    # Keep declaration-order fallback for legacy implicit ties between
    # distinct variants. Duplicate rules for one variant are ambiguous.
    def self.ambiguous_winners?(winners : Array(::Regex::Automata::PatternID), explicit : Array(Bool), variants : Array(T)) : Bool forall T
      return false if winners.size < 2
      return true if winners.count { |id| explicit[id.to_i] } > 1

      winners.map { |id| variants[id.to_i] }.uniq!.size < winners.size
    end

    # Check for problematic patterns like greedy .* or .+
    def check_for_greedy_all : Bool
      @hir.try(&.has_greedy_all?) || false
    end
  end
end
