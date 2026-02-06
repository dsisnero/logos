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
    def build_alternation(left : ThompsonRef, right : ThompsonRef) : ThompsonRef
      # Create union state that epsilon-transitions to both alternatives
      union_start = add_state(Union.new([left.start, right.start]))
      # Create common empty end state
      empty_end = add_state(Empty.new(StateID.new(0))) # placeholder
      # Patch both ends to point to common end
      update_transition_target(left.end, empty_end)
      update_transition_target(right.end, empty_end)
      ThompsonRef.new(union_start, empty_end)
    end

    # Build concatenation of two sub-NFAs
    def build_concatenation(first : ThompsonRef, second : ThompsonRef) : ThompsonRef
      # Patch the end of first sub-NFA to point to start of second
      update_transition_target(first.end, second.start)
      ThompsonRef.new(first.start, second.end)
    end

    # Build repetition (kleene star)
    def build_repetition(child : ThompsonRef, min : Int32, max : Int32?, pattern_id : PatternID = PatternID.new(0)) : ThompsonRef
      # Handle special cases
      if min == 0 && max.nil?
        # Kleene star: 0 or more repetitions
        # Create new end state (match state for empty string acceptance)
        new_end = add_state(Match.new(pattern_id))
        # Create start union: epsilon to child.start OR to new_end (skip)
        start_union = add_state(Union.new([child.start, new_end]))
        # Create loop union at child.end: epsilon to child.start (loop) OR to new_end
        loop_union = add_state(Union.new([child.start, new_end]))
        update_transition_target(child.end, loop_union)
        ThompsonRef.new(start_union, new_end)
      elsif min == 1 && max.nil?
        # Plus: 1 or more repetitions
        # Create new end state (match state for acceptance after at least one)
        new_end = add_state(Match.new(pattern_id))
        # Create loop union at child.end: epsilon to child.start (loop) OR to new_end
        loop_union = add_state(Union.new([child.start, new_end]))
        update_transition_target(child.end, loop_union)
        ThompsonRef.new(child.start, new_end)
      elsif min == 0 && max == 1
        # Optional: 0 or 1
        # Create union start: epsilon to child.start OR to child.end (skip)
        start_union = add_state(Union.new([child.start, child.end]))
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
