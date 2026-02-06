require "./nfa"
require "./byte_classes"
require "set"

module Regex::Automata::DFA
  alias StateID = Regex::Automata::StateID
  alias PatternID = Regex::Automata::PatternID

  # DFA state with transitions for each byte class
  class State
    getter id : StateID
    getter next : Array(StateID)  # indexed by byte class
    getter match : Array(PatternID)  # empty if not accepting

    def initialize(@id : StateID, byte_classes : Int32)
      @next = Array.new(byte_classes, StateID.new(-1))  # -1 = no transition
      @match = [] of PatternID
    end

    # Create a copy of this state with new ID
    def dup(new_id : StateID) : State
      state = State.new(new_id, @next.size)
      state.next.replace(@next.dup)
      state.match.replace(@match.dup)
      state
    end

    def set_transition(byte_class : Int32, target : StateID)
      @next[byte_class] = target
    end

    def add_match(pattern_id : PatternID)
      @match << pattern_id unless @match.includes?(pattern_id)
    end

    def accepting? : Bool
      !@match.empty?
    end
  end

  # Deterministic Finite Automaton
  class DFA
    getter states : Array(State)
    getter start : StateID
    getter byte_classes : Int32

    def initialize(@states : Array(State), @start : StateID, @byte_classes : Int32)
    end

    # Get number of states
    def size : Int32
      @states.size
    end

    # Get state by ID
    def [](id : StateID) : State
      @states[id.to_i]
    end

    # Remove dead states (unreachable or can't reach accept state)
    def remove_dead_states : DFA
      # Forward reachable from start
      forward = Set{@start}
      stack = [@start]
      while !stack.empty?
        state_id = stack.pop
        state = @states[state_id.to_i]
        state.next.each do |next_id|
          if next_id.to_i >= 0 && !forward.includes?(next_id)
            forward.add(next_id)
            stack.push(next_id)
          end
        end
      end

      # Backward reachable from accepting states
      backward = Set(StateID).new
      # Build reverse transitions
      reverse = Array(Set(StateID)).new(@states.size) { Set(StateID).new }
      @states.each_with_index do |state, i|
        state.next.each do |next_id|
          if next_id.to_i >= 0
            reverse[next_id.to_i].add(StateID.new(i))
          end
        end
      end

      # Start from accepting states
      stack.clear
      @states.each_with_index do |state, i|
        if state.accepting?
          state_id = StateID.new(i)
          backward.add(state_id)
          stack.push(state_id)
        end
      end

      # BFS from accepting states
      while !stack.empty?
        state_id = stack.pop
        reverse[state_id.to_i].each do |prev_id|
          unless backward.includes?(prev_id)
            backward.add(prev_id)
            stack.push(prev_id)
          end
        end
      end

      # Live states = intersection
      live = forward & backward
      return self if live.size == @states.size

      # Create mapping from old to new state IDs
      old_to_new = {} of StateID => StateID
      new_states = [] of State
      live.to_a.sort_by(&.to_i).each_with_index do |old_id, new_index|
        new_id = StateID.new(new_index)
        old_to_new[old_id] = new_id
        # Create copy of state with new ID
        old_state = @states[old_id.to_i]
        new_state = old_state.dup(new_id)
        new_states << new_state
      end

      # Update transitions in new states
      new_states.each do |state|
        state.next.each_with_index do |next_id, i|
          if next_id.to_i >= 0 && old_to_new.has_key?(next_id)
            state.next[i] = old_to_new[next_id]
          elsif next_id.to_i >= 0
            state.next[i] = StateID.new(-1)
          end
        end
      end

      # Update start state
      new_start = old_to_new[@start]? || StateID.new(0)

      DFA.new(new_states, new_start, @byte_classes)
    end

    # Reduce byte classes using equivalence analysis
    def reduce_byte_classes : DFA
      byte_classes = ByteClasses.from_dfa(self)
      byte_classes.apply_to_dfa(self)
    end
  end

  # Subset construction builder
  class Builder
    @nfa : NFA::NFA
    @dfa_states : Array(State)
    @state_map : Hash(Set(StateID), StateID)  # NFA state set -> DFA state ID
    @byte_classes : Int32

    def initialize(@nfa : NFA::NFA, @byte_classes : Int32 = 256)
      @dfa_states = [] of State
      @state_map = {} of Set(StateID) => StateID
    end

    # Build DFA from NFA using subset construction
    def build : DFA
      # Start with epsilon closure of NFA start state
      start_set = @nfa.epsilon_closure(Set{@nfa.start_unanchored})
      start_id = add_dfa_state(start_set)

      # Process queue of unprocessed DFA states
      queue = [start_id]
      processed = Set{start_id}

      while !queue.empty?
        dfa_id = queue.pop
        dfa_state = @dfa_states[dfa_id.to_i]

        # Find NFA set for this DFA state
        nfa_set = nil
        @state_map.each do |set, id|
          if id == dfa_id
            nfa_set = set
            break
          end
        end
        next if nfa_set.nil?  # Should not happen

        # For each byte class, compute transition
        @byte_classes.times do |byte_class|
          byte = byte_class.to_u8
          next_set = Set(StateID).new

          nfa_set.each do |nfa_id|
            # Get transitions for this byte from NFA state
            transitions = @nfa.transitions(nfa_id, byte)
            transitions.each do |next_nfa_id|
              next_set.add(next_nfa_id)
            end
          end

          next_set = @nfa.epsilon_closure(next_set)
          if !next_set.empty?
            next_id = @state_map[next_set]?
            if next_id.nil?
              next_id = add_dfa_state(next_set)
              unless processed.includes?(next_id)
                queue << next_id
                processed.add(next_id)
              end
            end
            dfa_state.set_transition(byte_class, next_id)
          end
        end
      end

      DFA.new(@dfa_states, start_id, @byte_classes)
    end

    private def add_dfa_state(nfa_set : Set(StateID)) : StateID
      dfa_id = StateID.new(@dfa_states.size)
      state = State.new(dfa_id, @byte_classes)

      # Check if any NFA state in set is a match
      nfa_set.each do |nfa_id|
        nfa_state = @nfa.states[nfa_id.to_i]
        if nfa_state.is_a?(NFA::Match)
          state.add_match(nfa_state.pattern_id)
        end
      end

      @dfa_states << state
      @state_map[nfa_set] = dfa_id
      dfa_id
    end
  end
end
