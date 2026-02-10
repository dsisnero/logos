require "./utf8_sequences"

module Regex::Automata::NFA
  alias StateID = Regex::Automata::StateID
  alias PatternID = Regex::Automata::PatternID
  # A transition between NFA states
  struct Transition
    # Range of bytes that trigger this transition
    getter start : UInt8
    getter end : UInt8
    # Target state ID
    getter next : StateID

    def initialize(@start : UInt8, @end : UInt8, @next : StateID)
    end

    # Check if byte is in range
    def matches?(byte : UInt8) : Bool
      byte >= @start && byte <= @end
    end
  end

  # Different types of NFA states
  alias State = ByteRange | Sparse | Look | Union | BinaryUnion | Capture | Match | Fail | Empty

  # Single byte range transition
  struct ByteRange
    getter trans : Transition

    def initialize(@trans : Transition)
    end
  end

  # Sparse transitions (multiple non-overlapping ranges)
  struct Sparse
    getter transitions : Array(Transition)

    def initialize(@transitions : Array(Transition))
    end
  end

  # Look-around assertion (word boundary, ^, $, etc.)
  struct Look
    enum Kind
      Start              # ^
      End                # $
      WordBoundary       # \b
      NonWordBoundary    # \B
      StartText          # \A
      EndText            # \z
      EndTextWithNewline # \Z
    end

    getter kind : Kind
    getter next : StateID

    def initialize(@kind : Kind, @next : StateID)
    end
  end

  # Union/alternation (epsilon transitions to multiple states)
  struct Union
    getter alternates : Array(StateID)

    def initialize(@alternates : Array(StateID))
    end
  end

  # Binary union (common case of 2 alternates)
  struct BinaryUnion
    getter alt1 : StateID
    getter alt2 : StateID

    def initialize(@alt1 : StateID, @alt2 : StateID)
    end
  end

  # Capture state (for capturing groups)
  struct Capture
    getter next : StateID
    getter pattern_id : PatternID
    getter group_index : Int32
    getter slot : Int32

    def initialize(@next : StateID, @pattern_id : PatternID, @group_index : Int32, @slot : Int32)
    end
  end

  # Match state (accepting state for a pattern)
  struct Match
    getter pattern_id : PatternID
    getter next : StateID?

    def initialize(@pattern_id : PatternID, @next : StateID? = nil)
    end
  end

  # Fail state (no transitions)
  struct Fail
    def initialize
    end
  end

  # Empty state (epsilon transition)
  struct Empty
    getter next : StateID

    def initialize(@next : StateID)
    end
  end

  # Reference to a sub-NFA (start and end states)
  struct ThompsonRef
    getter start : StateID
    getter end : StateID

    def initialize(@start : StateID, @end : StateID)
    end
  end

  # Thompson NFA builder
  class Builder
    @states : Array(State)
    @start_anchored : StateID
    @start_unanchored : StateID
    @start_pattern : Array(StateID)
    @utf8 : Bool

    def initialize(utf8 : Bool = true)
      @states = [] of State
      @start_anchored = StateID.new(0)
      @start_unanchored = StateID.new(0)
      @start_pattern = [] of StateID
      @utf8 = utf8

      # Create initial fail state
      add_state(Fail.new)
    end

    # Add a new state and return its ID
    def add_state(state : State) : StateID
      id = StateID.new(@states.size)
      @states << state
      id
    end

    # Set the unanchored start state
    def set_start_unanchored(id : StateID)
      @start_unanchored = id
    end

    # Set the anchored start state
    def set_start_anchored(id : StateID)
      @start_anchored = id
    end

    # Add a pattern start state
    def add_pattern_start(id : StateID)
      @start_pattern << id
    end

    # Build a literal pattern (sequence of bytes)
    def build_literal(bytes : Bytes, pattern_id : PatternID = PatternID.new(0)) : ThompsonRef
      # For empty literal, return a match state
      if bytes.empty?
        match_id = add_state(Match.new(pattern_id))
        return ThompsonRef.new(match_id, match_id)
      end

      # Build chain of byte range states
      start_id = nil
      prev_id = nil

      bytes.each do |byte|
        trans = Transition.new(byte, byte, StateID.new(0)) # placeholder
        state = ByteRange.new(trans)
        state_id = add_state(state)

        if prev_id
          # Update previous transition to point to this state
          update_transition_target(prev_id, state_id)
        else
          start_id = state_id
        end
        prev_id = state_id
      end

      # Last state should be a match
      match_id = add_state(Match.new(pattern_id))
      update_transition_target(prev_id, match_id) if prev_id

      ThompsonRef.new(start_id || match_id, match_id)
    end

    # Build alternation between two sub-NFAs
    def build_alternation(left : ThompsonRef, right : ThompsonRef, pattern_id : PatternID = PatternID.new(0)) : ThompsonRef
      # Create union state that epsilon-transitions to both alternatives
      union_start = add_state(Union.new([left.start, right.start]))
      # Create common match end state
      match_end = add_state(Match.new(pattern_id))
      # Patch both ends to point to common match state
      update_transition_target(left.end, match_end)
      update_transition_target(right.end, match_end)
      ThompsonRef.new(union_start, match_end)
    end

    # Build concatenation of two sub-NFAs
    def build_concatenation(first : ThompsonRef, second : ThompsonRef) : ThompsonRef
      # If first.end is a Match state, replace it with Empty to avoid intermediate matches
      replace_match_with_empty(first.end)
      # Patch the end of first sub-NFA to point to start of second
      update_transition_target(first.end, second.start)
      ThompsonRef.new(first.start, second.end)
    end

    # Build repetition (kleene star)
    def build_repetition(child : ThompsonRef, min : Int32, max : Int32?, greedy : Bool = true, pattern_id : PatternID = PatternID.new(0)) : ThompsonRef
      # Handle special cases
      if min == 0 && max.nil?
        # Kleene star: 0 or more repetitions
        # Create new end state (match state for empty string acceptance)
        new_end = add_state(Match.new(pattern_id))
        # Determine order based on greediness
        start_alternates = greedy ? [child.start, new_end] : [new_end, child.start]
        loop_alternates = greedy ? [child.start, new_end] : [new_end, child.start]
        # Create start union: epsilon to child.start OR to new_end (skip)
        start_union = add_state(Union.new(start_alternates))
        # Create loop union at child.end: epsilon to child.start (loop) OR to new_end
        loop_union = add_state(Union.new(loop_alternates))
        update_transition_target(child.end, loop_union)
        ThompsonRef.new(start_union, new_end)
      elsif min == 1 && max.nil?
        # Plus: 1 or more repetitions
        # Create new end state (match state for acceptance after at least one)
        new_end = add_state(Match.new(pattern_id))
        # Determine order based on greediness
        loop_alternates = greedy ? [child.start, new_end] : [new_end, child.start]
        # Create loop union at child.end: epsilon to child.start (loop) OR to new_end
        loop_union = add_state(Union.new(loop_alternates))
        update_transition_target(child.end, loop_union)
        ThompsonRef.new(child.start, new_end)
      elsif min == 0 && max == 1
        # Optional: 0 or 1
        # Determine order based on greediness
        alternates = greedy ? [child.start, child.end] : [child.end, child.start]
        # Create union start: epsilon to child.start OR to child.end (skip)
        start_union = add_state(Union.new(alternates))
        ThompsonRef.new(start_union, child.end)
      else
        # General case {min,max} - implement via concatenation of min copies
        # followed by optional copies up to max
        # For now, return child as placeholder
        child
      end
    end

    # Build character class
    def build_class(ranges : Array(Range(UInt8, UInt8)), negated : Bool = false, pattern_id : PatternID = PatternID.new(0)) : ThompsonRef
      if negated
        # Negated class - more complex, need multiple transitions
        # For now, return fail state placeholder
        fail_id = add_state(Fail.new)
        match_id = add_state(Match.new(pattern_id))
        update_transition_target(fail_id, match_id)
        ThompsonRef.new(fail_id, match_id)
      else
        # Convert ranges to transitions
        transitions = ranges.map do |range|
          Transition.new(range.begin, range.end, StateID.new(0))
        end

        class_state = if transitions.size == 1
                        add_state(ByteRange.new(transitions.first))
                      else
                        add_state(Sparse.new(transitions))
                      end

        match_id = add_state(Match.new(pattern_id))
        update_transition_target(class_state, match_id)
        ThompsonRef.new(class_state, match_id)
      end
    end

    # Build Unicode character class (codepoint ranges)
    def build_unicode_class(ranges : Array(Range(UInt32, UInt32)), negated : Bool = false, pattern_id : PatternID = PatternID.new(0)) : ThompsonRef
      if negated
        # TODO: implement negated Unicode class
        fail_id = add_state(Fail.new)
        match_id = add_state(Match.new(pattern_id))
        update_transition_target(fail_id, match_id)
        return ThompsonRef.new(fail_id, match_id)
      end

      # Convert each Unicode range to UTF-8 sequences
      sequences = [] of ::Regex::Automata::Utf8Sequence
      ranges.each do |range|
        start_char = range.begin.chr
        end_char = range.end.chr
        utf8_seq = ::Regex::Automata::Utf8Sequences.new(start_char, end_char)
        while seq = utf8_seq.next
          sequences << seq
        end
      end

      # Build alternation of all sequences
      if sequences.empty?
        # No sequences - empty match
        match_id = add_state(Match.new(pattern_id))
        ThompsonRef.new(match_id, match_id)
      elsif sequences.size == 1
        # Single sequence - build concatenation
        build_utf8_sequence(sequences.first, pattern_id)
      else
        # Multiple sequences - build alternation
        refs = sequences.map { |seq| build_utf8_sequence(seq, pattern_id) }
        # Build binary alternation tree
        result = refs.first
        refs[1..].each do |next_ref|
          result = build_alternation(result, next_ref, pattern_id)
        end
        result
      end
    end

    # Build a single UTF-8 sequence (concatenation of byte ranges)
    private def build_utf8_sequence(seq : ::Regex::Automata::Utf8Sequence, pattern_id : PatternID) : ThompsonRef
      # Build concatenation of byte ranges in sequence
      refs = seq.ranges.map do |range|
        build_class([range.start..range.end], false, pattern_id)
      end

      if refs.empty?
        match_id = add_state(Match.new(pattern_id))
        ThompsonRef.new(match_id, match_id)
      elsif refs.size == 1
        refs.first
      else
        # Build concatenation chain
        result = refs.first
        refs[1..].each do |next_ref|
          result = build_concatenation(result, next_ref)
        end
        result
      end
    end

    # Build dot metacharacter
    def build_dot(kind : Regex::Syntax::Hir::Dot, pattern_id : PatternID = PatternID.new(0)) : ThompsonRef
      case kind
      when Regex::Syntax::Hir::Dot::AnyByte
        # Match any single byte (0-255)
        build_class([0_u8..255_u8], false, pattern_id)
      when Regex::Syntax::Hir::Dot::AnyByteExceptLF
        # Match any byte except line feed (10)
        ranges = [] of Range(UInt8, UInt8)
        ranges << (0_u8..9_u8) if 0_u8 <= 9_u8
        ranges << (11_u8..255_u8) if 11_u8 <= 255_u8
        build_class(ranges, false, pattern_id)
      when Regex::Syntax::Hir::Dot::AnyByteExceptCRLF
        # Match any byte except carriage return (13) and line feed (10)
        ranges = [] of Range(UInt8, UInt8)
        # 0-9, 11-12, 14-255
        ranges << (0_u8..9_u8) if 0_u8 <= 9_u8
        ranges << (11_u8..12_u8) if 11_u8 <= 12_u8
        ranges << (14_u8..255_u8) if 14_u8 <= 255_u8
        build_class(ranges, false, pattern_id)
      when Regex::Syntax::Hir::Dot::AnyChar
        build_utf8_any_char(pattern_id)
      when Regex::Syntax::Hir::Dot::AnyCharExceptLF
        build_utf8_any_char_except_lf(pattern_id)
      when Regex::Syntax::Hir::Dot::AnyCharExceptCRLF
        build_utf8_any_char_except_crlf(pattern_id)
      else
        raise "Unsupported dot kind: #{kind}"
      end
    end

    # Build UTF-8 any character (Unicode scalar value)
    private def build_utf8_any_char(pattern_id : PatternID) : ThompsonRef
      # Four alternatives: 1-byte, 2-byte, 3-byte, 4-byte sequences
      # 1-byte: 0x00-0x7F
      single = build_class([0x00_u8..0x7F_u8], false, pattern_id)
      # 2-byte: first 0xC0-0xDF, second 0x80-0xBF
      second_first = build_class([0xC0_u8..0xDF_u8], false, pattern_id)
      second_second = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      double = build_concatenation(second_first, second_second)
      # 3-byte: first 0xE0-0xEF, second 0x80-0xBF, third 0x80-0xBF
      third_first = build_class([0xE0_u8..0xEF_u8], false, pattern_id)
      third_second = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      third_third = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      triple = build_concatenation(third_first, third_second)
      triple = build_concatenation(triple, third_third)
      # 4-byte: first 0xF0-0xF7, second 0x80-0xBF, third 0x80-0xBF, fourth 0x80-0xBF
      fourth_first = build_class([0xF0_u8..0xF7_u8], false, pattern_id)
      fourth_second = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      fourth_third = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      fourth_fourth = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      quadruple = build_concatenation(fourth_first, fourth_second)
      quadruple = build_concatenation(quadruple, fourth_third)
      quadruple = build_concatenation(quadruple, fourth_fourth)
      # Union all four alternatives
      alt1 = build_alternation(single, double, pattern_id)
      alt2 = build_alternation(alt1, triple, pattern_id)
      build_alternation(alt2, quadruple, pattern_id)
    end

    # Build UTF-8 any character except line feed
    private def build_utf8_any_char_except_lf(pattern_id : PatternID) : ThompsonRef
      # Single-byte range excluding LF (0x0A)
      single_ranges = [] of Range(UInt8, UInt8)
      single_ranges << (0x00_u8..0x09_u8) if 0x00_u8 <= 0x09_u8
      single_ranges << (0x0B_u8..0x7F_u8) if 0x0B_u8 <= 0x7F_u8
      single = build_class(single_ranges, false, pattern_id)
      # 2-byte, 3-byte, 4-byte sequences unchanged (they don't contain LF)
      second_first = build_class([0xC0_u8..0xDF_u8], false, pattern_id)
      second_second = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      double = build_concatenation(second_first, second_second)
      third_first = build_class([0xE0_u8..0xEF_u8], false, pattern_id)
      third_second = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      third_third = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      triple = build_concatenation(third_first, third_second)
      triple = build_concatenation(triple, third_third)
      fourth_first = build_class([0xF0_u8..0xF7_u8], false, pattern_id)
      fourth_second = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      fourth_third = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      fourth_fourth = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      quadruple = build_concatenation(fourth_first, fourth_second)
      quadruple = build_concatenation(quadruple, fourth_third)
      quadruple = build_concatenation(quadruple, fourth_fourth)
      # Union all four alternatives
      alt1 = build_alternation(single, double, pattern_id)
      alt2 = build_alternation(alt1, triple, pattern_id)
      build_alternation(alt2, quadruple, pattern_id)
    end

    # Build UTF-8 any character except carriage return and line feed
    private def build_utf8_any_char_except_crlf(pattern_id : PatternID) : ThompsonRef
      # Single-byte range excluding LF (0x0A) and CR (0x0D)
      single_ranges = [] of Range(UInt8, UInt8)
      single_ranges << (0x00_u8..0x09_u8) if 0x00_u8 <= 0x09_u8
      single_ranges << (0x0B_u8..0x0C_u8) if 0x0B_u8 <= 0x0C_u8
      single_ranges << (0x0E_u8..0x7F_u8) if 0x0E_u8 <= 0x7F_u8
      single = build_class(single_ranges, false, pattern_id)
      # 2-byte, 3-byte, 4-byte sequences unchanged (they don't contain LF or CR)
      second_first = build_class([0xC0_u8..0xDF_u8], false, pattern_id)
      second_second = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      double = build_concatenation(second_first, second_second)
      third_first = build_class([0xE0_u8..0xEF_u8], false, pattern_id)
      third_second = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      third_third = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      triple = build_concatenation(third_first, third_second)
      triple = build_concatenation(triple, third_third)
      fourth_first = build_class([0xF0_u8..0xF7_u8], false, pattern_id)
      fourth_second = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      fourth_third = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      fourth_fourth = build_class([0x80_u8..0xBF_u8], false, pattern_id)
      quadruple = build_concatenation(fourth_first, fourth_second)
      quadruple = build_concatenation(quadruple, fourth_third)
      quadruple = build_concatenation(quadruple, fourth_fourth)
      # Union all four alternatives
      alt1 = build_alternation(single, double, pattern_id)
      alt2 = build_alternation(alt1, triple, pattern_id)
      build_alternation(alt2, quadruple, pattern_id)
    end

    # Build the final NFA
    def build : NFA
      NFA.new(@states, @start_anchored, @start_unanchored, @start_pattern, @utf8)
    end

    # Update the target of a state's transition
    # Used internally to patch placeholder transitions
    def update_transition_target(state_id : StateID, target_id : StateID)
      state = @states[state_id.to_i]
      new_state = update_state_target(state, target_id)
      @states[state_id.to_i] = new_state
    end

    # Replace a Match state with an Empty state (for concatenation)
    # Returns the new Empty state's ID (same as input)
    def replace_match_with_empty(state_id : StateID) : StateID
      state = @states[state_id.to_i]
      case state
      when Match
        # Create Empty state with same next target (if any)
        next_id = state.next || StateID.new(0)
        @states[state_id.to_i] = Empty.new(next_id)
      else
        # Not a Match, leave unchanged
      end
      state_id
    end

    private def update_state_target(state : State, target_id : StateID) : State
      case state
      when ByteRange
        trans = state.trans
        ByteRange.new(Transition.new(trans.start, trans.end, target_id))
      when Sparse
        new_transitions = state.transitions.map do |trans|
          Transition.new(trans.start, trans.end, target_id)
        end
        Sparse.new(new_transitions)
      when Look
        Look.new(state.kind, target_id)
      when Capture
        Capture.new(target_id, state.pattern_id, state.group_index, state.slot)
      when Empty
        Empty.new(target_id)
      when Match
        Match.new(state.pattern_id, target_id)
      when Union
        # Add target to alternates (creates new union with additional epsilon transition)
        Union.new(state.alternates + [target_id])
      when BinaryUnion
        # Convert to Union with 3 alternates
        Union.new([state.alt1, state.alt2, target_id])
      when Fail
        # Fail states have no outgoing transitions
        state
      else
        # Should never happen (exhaustive case)
        state
      end
    end
  end

  # Thompson NFA
  class NFA
    getter states : Array(State)
    getter start_anchored : StateID
    getter start_unanchored : StateID
    getter start_pattern : Array(StateID)
    getter? utf8 : Bool

    def initialize(@states : Array(State), @start_anchored : StateID,
                   @start_unanchored : StateID, @start_pattern : Array(StateID),
                   @utf8 : Bool)
    end

    # Get number of states
    def size : Int32
      @states.size
    end

    # Compute epsilon closure of a set of NFA states
    def epsilon_closure(states : Set(StateID)) : Set(StateID)
      stack = states.to_a
      closure = Set(StateID).new(states)

      while !stack.empty?
        state_id = stack.pop
        state = @states[state_id.to_i]

        case state
        when Empty
          next_id = state.next
          unless closure.includes?(next_id)
            closure.add(next_id)
            stack.push(next_id)
          end
        when Union
          state.alternates.each do |alt_id|
            unless closure.includes?(alt_id)
              closure.add(alt_id)
              stack.push(alt_id)
            end
          end
        when BinaryUnion
          unless closure.includes?(state.alt1)
            closure.add(state.alt1)
            stack.push(state.alt1)
          end
          unless closure.includes?(state.alt2)
            closure.add(state.alt2)
            stack.push(state.alt2)
          end
        when Look, Capture
          # These have a single next pointer (epsilon transition)
          next_id = state.next
          unless closure.includes?(next_id)
            closure.add(next_id)
            stack.push(next_id)
          end
        when Match
          # Match states have optional epsilon transition via next
          if next_id = state.next
            unless closure.includes?(next_id)
              closure.add(next_id)
              stack.push(next_id)
            end
          end
        when Fail, ByteRange, Sparse
          # No epsilon transitions
        end
      end

      closure
    end

    # Get transitions from a state for a given byte
    def transitions(state_id : StateID, byte : UInt8) : Set(StateID)
      state = @states[state_id.to_i]
      result = Set(StateID).new

      case state
      when ByteRange
        result.add(state.trans.next) if state.trans.matches?(byte)
      when Sparse
        state.transitions.each do |trans|
          result.add(trans.next) if trans.matches?(byte)
        end
      end

      result
    end
  end
end
