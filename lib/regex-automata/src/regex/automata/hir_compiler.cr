require "./nfa"

module Regex::Automata
  # Compiler that converts HIR (High-level Intermediate Representation)
  # to Thompson NFA
  class HirCompiler
    @builder : NFA::Builder
    @pattern_id : PatternID

    def initialize(utf8 : Bool = true)
      @builder = NFA::Builder.new(utf8: utf8)
      @pattern_id = PatternID.new(0)
    end

    # Compile a Hir::Hir to NFA
    def compile(hir : Regex::Syntax::Hir::Hir, pattern_id : PatternID = PatternID.new(0)) : NFA::NFA
      @pattern_id = pattern_id
      ref = compile_node(hir.node)
      @builder.set_start_unanchored(ref.start)
      @builder.build
    end

    # Compile multiple patterns into a single NFA
    def compile_multi(hirs : Array(Regex::Syntax::Hir::Hir)) : NFA::NFA
      pattern_starts = [] of StateID

      hirs.each_with_index do |hir, i|
        @pattern_id = PatternID.new(i)
        ref = compile_node(hir.node)
        @builder.add_pattern_start(ref.start)
        pattern_starts << ref.start
      end

      # Create union start state that epsilon-transitions to all pattern starts
      if pattern_starts.empty?
        # No patterns - create empty match state
        empty_match = @builder.add_state(NFA::Match.new(PatternID.new(0)))
        @builder.set_start_unanchored(empty_match)
      elsif pattern_starts.size == 1
        # Single pattern - use its start directly
        @builder.set_start_unanchored(pattern_starts.first)
      else
        # Multiple patterns - create union state
        union_start = @builder.add_state(NFA::Union.new(pattern_starts))
        @builder.set_start_unanchored(union_start)
      end

      @builder.build
    end

    private def compile_node(node : Regex::Syntax::Hir::Node) : NFA::ThompsonRef
      case node
      when Regex::Syntax::Hir::Empty
        compile_empty(node)
      when Regex::Syntax::Hir::Literal
        compile_literal(node)
      when Regex::Syntax::Hir::CharClass
        compile_char_class(node)
      when Regex::Syntax::Hir::UnicodeClass
        compile_unicode_class(node)
      when Regex::Syntax::Hir::Look
        compile_look(node)
      when Regex::Syntax::Hir::Repetition
        compile_repetition(node)
      when Regex::Syntax::Hir::Capture
        compile_capture(node)
      when Regex::Syntax::Hir::Concat
        compile_concat(node)
      when Regex::Syntax::Hir::Alternation
        compile_alternation(node)
      when Regex::Syntax::Hir::DotNode
        compile_dot(node)
      else
        raise "Unsupported HIR node type: #{node.class}"
      end
    end

    private def compile_empty(node : Regex::Syntax::Hir::Empty) : NFA::ThompsonRef
      # Empty pattern matches nothing - create a match state
      match_id = @builder.add_state(NFA::Match.new(@pattern_id))
      NFA::ThompsonRef.new(match_id, match_id)
    end

    private def compile_literal(node : Regex::Syntax::Hir::Literal) : NFA::ThompsonRef
      @builder.build_literal(node.bytes, @pattern_id)
    end

    private def compile_char_class(node : Regex::Syntax::Hir::CharClass) : NFA::ThompsonRef
      @builder.build_class(node.intervals, node.negated, @pattern_id)
    end

    private def compile_unicode_class(node : Regex::Syntax::Hir::UnicodeClass) : NFA::ThompsonRef
      @builder.build_unicode_class(node.intervals, node.negated, @pattern_id)
    end

    private def compile_dot(node : Regex::Syntax::Hir::DotNode) : NFA::ThompsonRef
      @builder.build_dot(node.kind, @pattern_id)
    end

    private def compile_look(node : Regex::Syntax::Hir::Look) : NFA::ThompsonRef
      # Convert Hir::Look::Kind to NFA::Look::Kind
      kind = case node.kind
      when Regex::Syntax::Hir::Look::Kind::Start
        NFA::Look::Kind::Start
      when Regex::Syntax::Hir::Look::Kind::End
        NFA::Look::Kind::End
      when Regex::Syntax::Hir::Look::Kind::WordBoundary
        NFA::Look::Kind::WordBoundary
      when Regex::Syntax::Hir::Look::Kind::NonWordBoundary
        NFA::Look::Kind::NonWordBoundary
      when Regex::Syntax::Hir::Look::Kind::StartText
        NFA::Look::Kind::StartText
      when Regex::Syntax::Hir::Look::Kind::EndText
        NFA::Look::Kind::EndText
      when Regex::Syntax::Hir::Look::Kind::EndTextWithNewline
        NFA::Look::Kind::EndTextWithNewline
      else
        raise "Unsupported look kind: #{node.kind}"
      end

      # Create look state with placeholder next
      look_id = @builder.add_state(NFA::Look.new(kind, StateID.new(0)))
      # Create match state
      match_id = @builder.add_state(NFA::Match.new(@pattern_id))
      # Update look to point to match
      @builder.update_transition_target(look_id, match_id)
      NFA::ThompsonRef.new(look_id, match_id)
    end

    private def compile_repetition(node : Regex::Syntax::Hir::Repetition) : NFA::ThompsonRef
      child_ref = compile_node(node.sub)
      @builder.build_repetition(child_ref, node.min, node.max, node.greedy, @pattern_id)
    end

    private def compile_capture(node : Regex::Syntax::Hir::Capture) : NFA::ThompsonRef
      # For now, treat capture same as its child
      # TODO: Implement proper capture states
      compile_node(node.sub)
    end

    private def compile_concat(node : Regex::Syntax::Hir::Concat) : NFA::ThompsonRef
      # Build concatenation of children
      refs = node.children.map { |child| compile_node(child) }

      if refs.empty?
        compile_empty(Regex::Syntax::Hir::Empty.new)
      else
        # Chain refs together
        result = refs.first
        refs[1..].each do |next_ref|
          result = @builder.build_concatenation(result, next_ref)
        end
        result
      end
    end

    private def compile_alternation(node : Regex::Syntax::Hir::Alternation) : NFA::ThompsonRef
      # Build alternation of children
      refs = node.children.map { |child| compile_node(child) }

      if refs.empty?
        compile_empty(Regex::Syntax::Hir::Empty.new)
      elsif refs.size == 1
        refs.first
      else
        # Build binary tree of alternations
        result = refs.first
        refs[1..].each do |next_ref|
           result = @builder.build_alternation(result, next_ref, @pattern_id)
        end
        result
      end
    end
  end
end