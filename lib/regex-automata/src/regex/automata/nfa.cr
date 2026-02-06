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
  alias State = ByteRange | Sparse | Look | Union | BinaryUnion | Capture | Match | Fail

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
      Start           # ^
      End             # $
      WordBoundary    # \b
      NonWordBoundary # \B
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

    def initialize(@pattern_id : PatternID)
    end
  end

  # Fail state (no transitions)
  struct Fail
    def initialize
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

    # Build a literal pattern (sequence of bytes)
    def build_literal(bytes : Bytes) : StateID
      # For empty literal, return a match state?
       return add_state(Match.new(PatternID.new(0))) if bytes.empty?

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
       match_id = add_state(Match.new(PatternID.new(0)))
       update_transition_target(prev_id, match_id) if prev_id

       start_id || match_id
    end

    # Build alternation between two sub-NFAs
    def build_alternation(left_id : StateID, right_id : StateID) : StateID
      # Create union state that epsilon-transitions to both alternatives
      union_id = add_state(Union.new([left_id, right_id]))
      union_id
    end

    # Build concatenation of two sub-NFAs
    def build_concatenation(first_id : StateID, second_id : StateID) : StateID
      # For concatenation A B, we need to connect all match states of A
      # to the start of B. This is complex without full graph manipulation.
      # For now, a simplified approach
      first_id
    end

    # Build repetition (kleene star)
    def build_repetition(child_id : StateID, min : Int32, max : Int32?) : StateID
      # TODO: Implement proper repetition construction
      child_id
    end

    # Build character class
    def build_class(ranges : Array(Range(UInt8, UInt8)), negated : Bool = false) : StateID
      if negated
        # Negated class - more complex, need multiple transitions
        # For now, return fail state placeholder
      add_state(Fail.new)
      else
        # Convert ranges to transitions
        transitions = ranges.map do |range|
          Transition.new(range.begin, range.end, StateID.new(0))
         end

         if transitions.size == 1
          add_state(ByteRange.new(transitions.first))
        else
          add_state(Sparse.new(transitions))
        end
      end
    end

    # Build the final NFA
    def build : NFA
      NFA.new(@states, @start_anchored, @start_unanchored, @start_pattern, @utf8)
    end

    private def update_transition_target(state_id : StateID, target_id : StateID)
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
      when Union, BinaryUnion, Match, Fail
        # These states don't have a single next pointer
        # Union/BinaryUnion have multiple alternates, Match/Fail have none
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
  end
end
